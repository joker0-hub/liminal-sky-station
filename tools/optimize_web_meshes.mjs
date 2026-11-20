import { NodeIO, Primitive, VertexLayout } from '@gltf-transform/core';
import { KHRONOS_EXTENSIONS } from '@gltf-transform/extensions';
import { simplifyPrimitive } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';

const io = new NodeIO()
    .registerExtensions(KHRONOS_EXTENSIONS)
    .setVertexLayout(VertexLayout.SEPARATE);
await MeshoptSimplifier.ready;

for (const path of process.argv.slice(2)) {
    const document = await io.read(path);
    let original = 0;
    let simplified = 0;
    for (const mesh of document.getRoot().listMeshes()) {
        for (const primitive of mesh.listPrimitives()) {
            const count = primitive.getIndices()?.getCount() ?? 0;
            if (primitive.getMode() !== Primitive.Mode.TRIANGLES || count < 6000) continue;
            if (primitive.getMaterial()?.getAlphaMode() === 'BLEND') continue;
            simplifyPrimitive(primitive, {
                simplifier: MeshoptSimplifier,
                ratio: 0.38,
                error: 0.003,
                lockBorder: true,
            });
            original += count;
            simplified += primitive.getIndices().getCount();
        }
    }
    await io.write(path, document);
    console.log(`${path}: ${original / 3} → ${simplified / 3} triangles in simplified surfaces`);
}
