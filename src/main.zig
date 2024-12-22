// configurable_consts: {
const Coord = u8;
const height = 32;
const width = 32;
comptime {
    for (.{ width, height }) |dim|
        assert(dim - 1 <= math.maxInt(Coord));

    assert(initial_len <= width * height);
}
const initial_len = 5;
const tile = struct {
    const fill = struct {
        const h = tile.h - 1;
        const w = tile.w - 1;
    };
    const h = 12;
    const w = 12;
};
// break :configurable_consts; }

const Direction = enum { right, left, down, up };
const Pos = struct {
    x: Coord,
    y: Coord,
    fn chooseAt(random: std.Random) @This() {
        return .{
            .x = random.uintLessThanBiased(Coord, width),
            .y = random.uintLessThanBiased(Coord, height),
        };
    }
};
const assert = debug.assert;
const debug = std.debug;
const math = std.math;
const mem = std.mem;
const posix = std.posix;
const std = @import("std");

fn rgbaFromHsl(hsl: struct { f32, f32, f32 }) zove.graphics.Rgba {
    var h, var s, var l, const a = hsl ++ .{1};
    l /= 255;
    if (s <= 0)
        return .{ .r = l, .g = l, .b = l, .a = a };
    h, s = .{ h / 256 * 6, s / 255 };
    const c = (1 - @abs(2 * l - 1)) * s;
    const x = (1 - @abs(@mod(h, 2) - 1)) * c;
    const m = l - 0.5 * c;
    const r, const g, const b = if (h < 1)
        .{ c, x, 0 }
    else if (h < 2)
        .{ x, c, 0 }
    else if (h < 3)
        .{ 0, c, x }
    else if (h < 4)
        .{ 0, x, c }
    else if (h < 5)
        .{ x, 0, c }
    else
        .{ c, 0, x };
    return .{
        .r = r + m,
        .g = g + m,
        .b = b + m,
        .a = a,
    };
}

const o = struct { // gl-bal_vars
    var snake = std.BoundedArray(Pos, width * height){};
    var maybe_dir: ?Direction = undefined;
    var time: f32 = undefined;

    var lum: f32 = undefined;
    var food: Pos = undefined;

    var random: std.Random = undefined;
    var prng: @TypeOf(o.random).DefaultPrng = undefined;
};

pub const zove = struct {
    usingnamespace @import("zove.libretro").zove;

    pub fn load() !void {
        o.snake.clear();
        o.snake.appendNTimesAssumeCapacity(.{ .x = width / 2, .y = height / 2 }, initial_len);

        o.maybe_dir = null;
        o.time = 0;

        o.lum = 0;

        {
            var seed: u64 = undefined;
            try posix.getrandom(mem.asBytes(&seed));
            o.prng = @TypeOf(o.prng).init(seed);
        }
        o.random = o.prng.random();
        o.food = Pos.chooseAt(o.random);
    }

    pub fn conf(t: *zove.Conf) !void {
        t.width = width * tile.w;
        t.height = height * tile.h;
    }

    pub fn update(_: f32) !void { // -dt
        o.time += 1;
        if (o.time >= math.maxInt(u24))
            o.time = 0;

        o.lum = @sin(o.time) * 8 + 40;

        inline for (@typeInfo(Direction).@"enum".fields) |dir|
            if (zove.joystick.isDown(0, @field(zove.joystick.GamepadButton, dir.name))) {
                o.maybe_dir = @field(Direction, dir.name);
                break;
            };

        if (0 != @mod(o.time, 5))
            return;

        var head = o.snake.get(o.snake.len - 1);

        if (o.maybe_dir) |dir| {
            switch (dir) {
                .up => head.y -= 1,
                .down => head.y += 1,
                .left => head.x -= 1,
                .right => head.x += 1,
            }
            o.snake.appendAssumeCapacity(head);
        }

        if (0 == head.x or head.x == width or 0 == head.y or head.y == height)
            try load();

        if (null != o.maybe_dir)
            for (o.snake.slice()[0 .. o.snake.len - 1]) |non_head|
                if (head.x == non_head.x and head.y == non_head.y) {
                    try load();
                    break;
                };

        if (head.x == o.food.x and head.y == o.food.y)
            o.food = Pos.chooseAt(o.random)
        else
            _ = o.snake.orderedRemove(0);
    }

    pub fn draw() !void {
        zove.graphics.setBackgroundColor(rgbaFromHsl(.{ o.time, 128, o.lum }));
        zove.graphics.clear();

        zove.graphics.setColor(rgbaFromHsl(.{ o.time / 100, 128, o.lum + 10 }));
        {
            var y: u24 = 0;
            while (y < height) : (y += 1) {
                var x: u24 = 0;
                while (x < width) : (x += 1)
                    zove.graphics.rectangle(.fill, x * tile.w, y * tile.h, tile.fill.w, tile.fill.h);
            }
        }

        zove.graphics.setColor(.{ .r = 1, .g = 1, .b = 1 });
        for (o.snake.slice()) |member|
            zove.graphics.rectangle(.fill, member.x * tile.w, member.y * tile.h, tile.fill.w, tile.fill.h);

        // zove.graphics.setColor(.{ .r = 1, .g = 1, .b = 1 });
        zove.graphics.rectangle(.fill, o.food.x * tile.w, o.food.y * tile.h, tile.fill.w, tile.fill.h);
    }
};
