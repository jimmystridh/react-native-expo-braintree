import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { readPackageMetadata } from '../plugin/packageMetadata';

let fixture: string;

beforeEach(() => {
  fixture = mkdtempSync(join(tmpdir(), 'braintree-plugin-'));
});

afterEach(() => {
  rmSync(fixture, { recursive: true, force: true });
});

const packageMetadata = {
  name: 'react-native-expo-braintree',
  version: '4.0.1',
};

it.each(['src/plugin', 'lib/commonjs/plugin', 'lib/module/plugin'])(
  'reads package metadata from %s',
  (directory) => {
    const pluginDirectory = join(fixture, directory);
    mkdirSync(pluginDirectory, { recursive: true });
    writeFileSync(
      join(fixture, 'package.json'),
      JSON.stringify(packageMetadata)
    );
    writeFileSync(
      join(pluginDirectory, '..', 'package.json'),
      '{"type":"commonjs"}'
    );

    expect(readPackageMetadata(pluginDirectory)).toEqual(packageMetadata);
  }
);

it('supports symlinked installs', () => {
  const source = join(fixture, 'package');
  mkdirSync(join(source, 'src/plugin'), { recursive: true });
  writeFileSync(join(source, 'package.json'), JSON.stringify(packageMetadata));
  const link = join(fixture, 'linked-package');
  symlinkSync(source, link, 'dir');

  expect(readPackageMetadata(join(link, 'src/plugin'))).toEqual(
    packageMetadata
  );
});

it('preserves malformed package errors', () => {
  writeFileSync(join(fixture, 'package.json'), '{invalid');

  expect(() => readPackageMetadata(fixture)).toThrow(SyntaxError);
});

it('reports an absent package instead of reading another package', () => {
  writeFileSync(join(fixture, 'package.json'), '{"name":"another-package"}');

  expect(() => readPackageMetadata(fixture)).toThrow(
    'Cannot locate react-native-expo-braintree/package.json'
  );
});

it('rejects package metadata without a version', () => {
  writeFileSync(
    join(fixture, 'package.json'),
    '{"name":"react-native-expo-braintree"}'
  );

  expect(() => readPackageMetadata(fixture)).toThrow('Missing package version');
});
