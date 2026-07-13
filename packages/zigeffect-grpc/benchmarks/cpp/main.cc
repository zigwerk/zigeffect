#include <grpcpp/grpcpp.h>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <new>
#include <string>

#include "conformance.grpc.pb.h"
#include "stats.grpc.pb.h"

namespace {
std::atomic<std::uint64_t> allocations{0};
std::atomic<std::uint64_t> frees{0};
std::atomic<std::uint64_t> allocated_bytes{0};
std::atomic<std::uint64_t> live_bytes{0};
std::atomic<std::uint64_t> peak_live_bytes{0};

struct AllocationHeader {
  void* base;
  std::size_t size;
};

void observe_peak(std::uint64_t value) {
  auto peak = peak_live_bytes.load(std::memory_order_relaxed);
  while (value > peak && !peak_live_bytes.compare_exchange_weak(
      peak, value, std::memory_order_relaxed)) {}
}

void* counted_allocate(std::size_t size, std::size_t alignment) {
  const auto total = size + alignment + sizeof(AllocationHeader);
  auto* base = std::malloc(total);
  if (base == nullptr) throw std::bad_alloc();
  auto candidate = reinterpret_cast<std::uintptr_t>(base) + sizeof(AllocationHeader);
  auto aligned = (candidate + alignment - 1) & ~(alignment - 1);
  auto* header = reinterpret_cast<AllocationHeader*>(aligned) - 1;
  header->base = base;
  header->size = size;
  allocations.fetch_add(1, std::memory_order_relaxed);
  allocated_bytes.fetch_add(size, std::memory_order_relaxed);
  observe_peak(live_bytes.fetch_add(size, std::memory_order_relaxed) + size);
  return reinterpret_cast<void*>(aligned);
}

void counted_free(void* pointer) noexcept {
  if (pointer == nullptr) return;
  auto* header = reinterpret_cast<AllocationHeader*>(pointer) - 1;
  live_bytes.fetch_sub(header->size, std::memory_order_relaxed);
  frees.fetch_add(1, std::memory_order_relaxed);
  std::free(header->base);
}
}  // namespace

void* operator new(std::size_t size) { return counted_allocate(size, alignof(std::max_align_t)); }
void* operator new[](std::size_t size) { return counted_allocate(size, alignof(std::max_align_t)); }
void* operator new(std::size_t size, std::align_val_t alignment) { return counted_allocate(size, static_cast<std::size_t>(alignment)); }
void* operator new[](std::size_t size, std::align_val_t alignment) { return counted_allocate(size, static_cast<std::size_t>(alignment)); }
void operator delete(void* pointer) noexcept { counted_free(pointer); }
void operator delete[](void* pointer) noexcept { counted_free(pointer); }
void operator delete(void* pointer, std::size_t) noexcept { counted_free(pointer); }
void operator delete[](void* pointer, std::size_t) noexcept { counted_free(pointer); }
void operator delete(void* pointer, std::align_val_t) noexcept { counted_free(pointer); }
void operator delete[](void* pointer, std::align_val_t) noexcept { counted_free(pointer); }
void operator delete(void* pointer, std::size_t, std::align_val_t) noexcept { counted_free(pointer); }
void operator delete[](void* pointer, std::size_t, std::align_val_t) noexcept { counted_free(pointer); }

class ConformanceService final : public zigeffect::grpc::v1::ConformanceService::Service {
  grpc::Status Unary(
      grpc::ServerContext*,
      const zigeffect::grpc::v1::UnaryRequest* request,
      zigeffect::grpc::v1::UnaryResponse* response) override {
    response->set_id(request->id());
    response->set_accepted_sequence(request->sequence());
    return grpc::Status::OK;
  }

  grpc::Status ClientStream(
      grpc::ServerContext*,
      grpc::ServerReader<zigeffect::grpc::v1::ClientStreamRequest>* reader,
      zigeffect::grpc::v1::ClientStreamResponse* response) override {
    zigeffect::grpc::v1::ClientStreamRequest request;
    std::int64_t count = 0;
    while (reader->Read(&request)) ++count;
    response->set_accepted_count(count);
    return grpc::Status::OK;
  }

  grpc::Status ServerStream(
      grpc::ServerContext*,
      const zigeffect::grpc::v1::ServerStreamRequest* request,
      grpc::ServerWriter<zigeffect::grpc::v1::ServerStreamResponse>* writer) override {
    for (std::int64_t sequence = 0; sequence < request->count(); ++sequence) {
      zigeffect::grpc::v1::ServerStreamResponse response;
      response.set_sequence(sequence);
      if (!writer->Write(response)) break;
    }
    return grpc::Status::OK;
  }

  grpc::Status BidiStream(
      grpc::ServerContext*,
      grpc::ServerReaderWriter<zigeffect::grpc::v1::BidiStreamResponse,
                               zigeffect::grpc::v1::BidiStreamRequest>* stream) override {
    zigeffect::grpc::v1::BidiStreamRequest request;
    while (stream->Read(&request)) {
      zigeffect::grpc::v1::BidiStreamResponse response;
      response.set_sequence(request.sequence());
      if (!stream->Write(response)) break;
    }
    return grpc::Status::OK;
  }
};

class StatsService final : public zigeffect::benchmark::v1::Stats::Service {
  grpc::Status Snapshot(
      grpc::ServerContext*,
      const zigeffect::benchmark::v1::Empty*,
      zigeffect::benchmark::v1::AllocationStats* response) override {
    response->set_allocations(allocations.load(std::memory_order_relaxed));
    response->set_frees(frees.load(std::memory_order_relaxed));
    response->set_allocated_bytes(allocated_bytes.load(std::memory_order_relaxed));
    response->set_live_bytes(live_bytes.load(std::memory_order_relaxed));
    response->set_peak_live_bytes(peak_live_bytes.load(std::memory_order_relaxed));
    return grpc::Status::OK;
  }
};

int main() {
  const auto* configured = std::getenv("PORT");
  const std::string port = configured == nullptr ? "8080" : configured;
  ConformanceService conformance;
  StatsService stats;
  grpc::ServerBuilder builder;
  builder.AddListeningPort("0.0.0.0:" + port, grpc::InsecureServerCredentials());
  builder.RegisterService(&conformance);
  builder.RegisterService(&stats);
  auto server = builder.BuildAndStart();
  if (!server) return 1;
  std::cout << "listening on " << port << std::endl;
  server->Wait();
  return 0;
}
