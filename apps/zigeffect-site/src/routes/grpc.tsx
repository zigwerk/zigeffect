import { Link, Meta, Title, useHead } from "@solidjs/meta";
import { GrpcPage } from "../GrpcPage";
import { SITE_URL, SOCIAL_IMAGE_URL } from "../seo";

const title = "Native gRPC and Connect for Zig — ZigEffect";
const description = "Build typed Zig gRPC services and SolidJS Connect clients from one Protobuf contract, with bounded streaming, Cloud Run hosting, causal evidence, and measured performance.";
const canonical = `${SITE_URL}/grpc`;
const schema = JSON.stringify({
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareSourceCode",
      name: "zigeffect-grpc",
      description,
      codeRepository: "https://github.com/zig-effect/zigeffect",
      programmingLanguage: "Zig",
      runtimePlatform: ["Linux", "Google Cloud Run"],
      targetProduct: { "@type": "SoftwareApplication", name: "ZigEffect" },
    },
    {
      "@type": "FAQPage",
      mainEntity: [
        { "@type": "Question", name: "Are we faster than Go?", acceptedAnswer: { "@type": "Answer", text: "In the latest same-receipt 1 KiB unary optimization diagnostic, ZigEffect reached 96.6% of grpc-go throughput and measured 13.4% higher throughput than Tonic. Results vary by host and workload." } },
        { "@type": "Question", name: "Is ZigEffect gRPC pure Zig?", acceptedAnswer: { "@type": "Answer", text: "It is a Zig-native implementation without the gRPC C core. nghttp2 supplies HTTP/2 and OpenSSL supplies TLS." } },
        { "@type": "Question", name: "Can it run on Cloud Run?", acceptedAnswer: { "@type": "Answer", text: "Yes. The server supports Cloud Run's h2c container contract, readiness, identity middleware, bounded resources, and graceful shutdown." } },
        { "@type": "Question", name: "Is it production verified?", acceptedAnswer: { "@type": "Answer", text: "It is production candidate pending native Linux amd64, a complete 24-hour soak, and deployed GCP qualification on committed source." } },
      ],
    },
  ],
});

export default function Route() {
  useHead({ tag: "script", id: "grpc-schema", props: { type: "application/ld+json", children: schema }, setting: { close: true } });
  return <><Title>{title}</Title><Meta name="description" content={description} /><Link rel="canonical" href={canonical} /><Meta property="og:title" content={title} /><Meta property="og:description" content={description} /><Meta property="og:image" content={SOCIAL_IMAGE_URL} /><Meta name="twitter:card" content="summary_large_image" /><Meta name="twitter:title" content={title} /><GrpcPage /></>;
}
