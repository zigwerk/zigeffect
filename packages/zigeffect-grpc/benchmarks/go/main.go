package main

import (
	"context"
	"net"
	"os"
	"runtime"
	"strconv"

	conformance "zigeffect-grpc-bench/gen/conformance"
	stats "zigeffect-grpc-bench/gen/stats"
	"google.golang.org/grpc"
)

type conformanceServer struct {
	conformance.UnimplementedConformanceServiceServer
}

func (conformanceServer) Unary(_ context.Context, request *conformance.UnaryRequest) (*conformance.UnaryResponse, error) {
	return &conformance.UnaryResponse{Id: request.Id, AcceptedSequence: request.Sequence}, nil
}

func (conformanceServer) ClientStream(stream grpc.ClientStreamingServer[conformance.ClientStreamRequest, conformance.ClientStreamResponse]) error {
	var count int64
	for {
		_, err := stream.Recv()
		if err != nil {
			return stream.SendAndClose(&conformance.ClientStreamResponse{AcceptedCount: count})
		}
		count++
	}
}

func (conformanceServer) ServerStream(request *conformance.ServerStreamRequest, stream grpc.ServerStreamingServer[conformance.ServerStreamResponse]) error {
	for sequence := int64(0); sequence < request.Count; sequence++ {
		if err := stream.Send(&conformance.ServerStreamResponse{Sequence: sequence}); err != nil {
			return err
		}
	}
	return nil
}

func (conformanceServer) BidiStream(stream grpc.BidiStreamingServer[conformance.BidiStreamRequest, conformance.BidiStreamResponse]) error {
	for {
		request, err := stream.Recv()
		if err != nil {
			return nil
		}
		if err := stream.Send(&conformance.BidiStreamResponse{Sequence: request.Sequence}); err != nil {
			return err
		}
	}
}

type statsServer struct {
	stats.UnimplementedStatsServer
}

func (statsServer) Snapshot(context.Context, *stats.Empty) (*stats.AllocationStats, error) {
	var memory runtime.MemStats
	runtime.ReadMemStats(&memory)
	return &stats.AllocationStats{
		Allocations:   memory.Mallocs,
		Frees:         memory.Frees,
		AllocatedBytes: memory.TotalAlloc,
		LiveBytes:     memory.Alloc,
		PeakLiveBytes: memory.Sys,
	}, nil
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if _, err := strconv.ParseUint(port, 10, 16); err != nil {
		panic(err)
	}
	listener, err := net.Listen("tcp", ":"+port)
	if err != nil {
		panic(err)
	}
	server := grpc.NewServer()
	conformance.RegisterConformanceServiceServer(server, conformanceServer{})
	stats.RegisterStatsServer(server, statsServer{})
	if err := server.Serve(listener); err != nil {
		panic(err)
	}
}
