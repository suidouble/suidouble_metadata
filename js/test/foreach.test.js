import { describe, expect, it } from "vitest";
import { Metadata } from "../src/Metadata";

describe("empty metadata", () => {
    const meta = new Metadata();

    let runCount = 0;
    meta.forEach((chunkId, bytes)=>{
        runCount++;
    });

	it("no callbacks on no chunks", () => {
		expect(runCount).toEqual(0);
	});
});


describe("empty metadata", () => {
    const meta = new Metadata();
    meta.set(1, 'test1', 'string');
    meta.set(2, 'test2', 'string');
    meta.set(3, 'test3', 'string');

    let runCount = 0;
    let runFor1 = false;
    let runFor2 = false;
    let runFor3 = false;
    meta.forEach((chunkId, bytes)=>{
        runCount++;

        if (chunkId == 1 && bytes.length == 6) { // length + 5 chars
            runFor1 = true;
        }
        if (chunkId == 2 && bytes.length == 6) {
            runFor2 = true;
        }
        if (chunkId == 3 && bytes.length == 6) {
            runFor3 = true;
        }
    });

	it("execute callback for each chunk", () => {
		expect(runCount).toEqual(3);
		expect(runFor1).toBeTruthy();
		expect(runFor2).toBeTruthy();
		expect(runFor3).toBeTruthy();
	});
});