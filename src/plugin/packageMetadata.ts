import { readFileSync } from 'fs';
import { dirname, join } from 'path';

export const readPackageMetadata = (
  moduleDirectory: string
): { name: string; version: string } => {
  let directory = moduleDirectory;
  for (;;) {
    let metadata: { name?: string; version?: string } | undefined;
    try {
      metadata = JSON.parse(
        readFileSync(join(directory, 'package.json'), 'utf8')
      );
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }
    if (metadata?.name === 'react-native-expo-braintree') {
      if (typeof metadata.version !== 'string') {
        throw new Error('Missing package version');
      }
      return { name: metadata.name, version: metadata.version };
    }
    const parent = dirname(directory);
    if (parent === directory) {
      throw new Error('Cannot locate react-native-expo-braintree/package.json');
    }
    directory = parent;
  }
};
