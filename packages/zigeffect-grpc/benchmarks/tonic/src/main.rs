use std::alloc::{GlobalAlloc, Layout, System};
use std::pin::Pin;
use std::sync::atomic::{AtomicU64, Ordering};
use tokio_stream::{wrappers::ReceiverStream, Stream, StreamExt};
use tonic::{transport::Server, Request, Response, Status};

mod conformance {
    tonic::include_proto!("zigeffect.grpc.v1");
}
mod stats {
    tonic::include_proto!("zigeffect.benchmark.v1");
}

struct CountingAllocator;
static ALLOCATIONS: AtomicU64 = AtomicU64::new(0);
static FREES: AtomicU64 = AtomicU64::new(0);
static ALLOCATED_BYTES: AtomicU64 = AtomicU64::new(0);
static LIVE_BYTES: AtomicU64 = AtomicU64::new(0);
static PEAK_LIVE_BYTES: AtomicU64 = AtomicU64::new(0);

#[global_allocator]
static ALLOCATOR: CountingAllocator = CountingAllocator;

unsafe impl GlobalAlloc for CountingAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let pointer = System.alloc(layout);
        if !pointer.is_null() {
            ALLOCATIONS.fetch_add(1, Ordering::Relaxed);
            ALLOCATED_BYTES.fetch_add(layout.size() as u64, Ordering::Relaxed);
            let live = LIVE_BYTES.fetch_add(layout.size() as u64, Ordering::Relaxed) + layout.size() as u64;
            PEAK_LIVE_BYTES.fetch_max(live, Ordering::Relaxed);
        }
        pointer
    }

    unsafe fn dealloc(&self, pointer: *mut u8, layout: Layout) {
        System.dealloc(pointer, layout);
        FREES.fetch_add(1, Ordering::Relaxed);
        LIVE_BYTES.fetch_sub(layout.size() as u64, Ordering::Relaxed);
    }

    unsafe fn realloc(&self, pointer: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
        let replacement = System.realloc(pointer, layout, new_size);
        if !replacement.is_null() {
            if new_size > layout.size() {
                let growth = (new_size - layout.size()) as u64;
                ALLOCATED_BYTES.fetch_add(growth, Ordering::Relaxed);
                let live = LIVE_BYTES.fetch_add(growth, Ordering::Relaxed) + growth;
                PEAK_LIVE_BYTES.fetch_max(live, Ordering::Relaxed);
            } else {
                LIVE_BYTES.fetch_sub((layout.size() - new_size) as u64, Ordering::Relaxed);
            }
        }
        replacement
    }
}

#[derive(Default)]
struct Conformance;

#[tonic::async_trait]
impl conformance::conformance_service_server::ConformanceService for Conformance {
    async fn unary(
        &self,
        request: Request<conformance::UnaryRequest>,
    ) -> Result<Response<conformance::UnaryResponse>, Status> {
        let request = request.into_inner();
        Ok(Response::new(conformance::UnaryResponse {
            id: request.id,
            accepted_sequence: request.sequence,
        }))
    }

    async fn client_stream(
        &self,
        request: Request<tonic::Streaming<conformance::ClientStreamRequest>>,
    ) -> Result<Response<conformance::ClientStreamResponse>, Status> {
        let mut stream = request.into_inner();
        let mut count = 0;
        while stream.message().await?.is_some() {
            count += 1;
        }
        Ok(Response::new(conformance::ClientStreamResponse { accepted_count: count }))
    }

    type ServerStreamStream = Pin<Box<dyn Stream<Item = Result<conformance::ServerStreamResponse, Status>> + Send>>;

    async fn server_stream(
        &self,
        request: Request<conformance::ServerStreamRequest>,
    ) -> Result<Response<Self::ServerStreamStream>, Status> {
        let count = request.into_inner().count;
        let (sender, receiver) = tokio::sync::mpsc::channel(16);
        tokio::spawn(async move {
            for sequence in 0..count {
                if sender.send(Ok(conformance::ServerStreamResponse { sequence })).await.is_err() {
                    return;
                }
            }
        });
        Ok(Response::new(Box::pin(ReceiverStream::new(receiver))))
    }

    type BidiStreamStream = Pin<Box<dyn Stream<Item = Result<conformance::BidiStreamResponse, Status>> + Send>>;

    async fn bidi_stream(
        &self,
        request: Request<tonic::Streaming<conformance::BidiStreamRequest>>,
    ) -> Result<Response<Self::BidiStreamStream>, Status> {
        let mut inbound = request.into_inner();
        let (sender, receiver) = tokio::sync::mpsc::channel(16);
        tokio::spawn(async move {
            while let Some(item) = inbound.next().await {
                let request = match item {
                    Ok(request) => request,
                    Err(_) => return,
                };
                if sender.send(Ok(conformance::BidiStreamResponse { sequence: request.sequence })).await.is_err() {
                    return;
                }
            }
        });
        Ok(Response::new(Box::pin(ReceiverStream::new(receiver))))
    }
}

#[derive(Default)]
struct AllocationStats;

#[tonic::async_trait]
impl stats::stats_server::Stats for AllocationStats {
    async fn snapshot(
        &self,
        _: Request<stats::Empty>,
    ) -> Result<Response<stats::AllocationStats>, Status> {
        Ok(Response::new(stats::AllocationStats {
            allocations: ALLOCATIONS.load(Ordering::Relaxed),
            frees: FREES.load(Ordering::Relaxed),
            allocated_bytes: ALLOCATED_BYTES.load(Ordering::Relaxed),
            live_bytes: LIVE_BYTES.load(Ordering::Relaxed),
            peak_live_bytes: PEAK_LIVE_BYTES.load(Ordering::Relaxed),
        }))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_owned());
    let address = format!("0.0.0.0:{port}").parse()?;
    Server::builder()
        .add_service(conformance::conformance_service_server::ConformanceServiceServer::new(Conformance))
        .add_service(stats::stats_server::StatsServer::new(AllocationStats))
        .serve(address)
        .await?;
    Ok(())
}
