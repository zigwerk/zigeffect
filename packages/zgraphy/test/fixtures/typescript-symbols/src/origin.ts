export class Service {
  static make(): Service { return new Service(); }
  doThing(): number { return 1; }
}

export interface Contract { readonly id: string }
export function validate(value: string): boolean { return value.length > 0; }
export default function makeThing(): Service { return new Service(); }

