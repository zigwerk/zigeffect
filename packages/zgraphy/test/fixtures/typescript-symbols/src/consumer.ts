import { PublicService, check, api, createThing } from "./barrel";
import type { PublicContract } from "./barrel";
import type { AliasedService } from "./local-barrel";
import { OtherService } from "./other";
import { DeepService } from "./chain-17";
import { validate as cycleValidate } from "./cycle-a";

declare function encode(value: string): string;

export class Controller {
  constructor(private readonly service: PublicService) {}

  run(input: PublicContract): number {
    const local = new PublicService();
    const other = new OtherService();
    const deep = new DeepService();
    check(input.id);
    cycleValidate(input.id);
    createThing();
    api.validate(input.id);
    PublicService.make();
    other.doThing();
    deep.doThing();
    encode(input.id);
    return this.service.doThing() + local.doThing();
  }

  closure(service: AliasedService): () => number {
    return () => service.doThing();
  }

  unsafe(untyped, values: PublicService[]): number {
    untyped.doThing();
    return values[0].doThing();
  }
}
