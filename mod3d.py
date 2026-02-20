import socket
import struct
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from mpl_toolkits.mplot3d.art3d import Poly3DCollection, Line3DCollection


UDP_IP = "10.10.10.1" # must match ip dest (frame_gen)
UDP_PORT = 4096 # muste match udp port (frame_gen)
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((UDP_IP, UDP_PORT))
sock.setblocking(False)


SENSITIVITY = 0.5   


L, W, T = 5.0, 3.0, 0.8

base_vertices = np.array([
    [-L/2, -W/2, -T/2],
    [ L/2, -W/2, -T/2],
    [ L/2,  W/2, -T/2],
    [-L/2,  W/2, -T/2],
    [-L/2, -W/2,  T/2],
    [ L/2, -W/2,  T/2],
    [ L/2,  W/2,  T/2],
    [-L/2,  W/2,  T/2],
], dtype=float)

faces_idx = [
    [0, 1, 2, 3],  # bottom
    [4, 5, 6, 7],  # top
    [0, 1, 5, 4],
    [1, 2, 6, 5],
    [2, 3, 7, 6],
    [3, 0, 4, 7],
]

edges_idx = [
    [0,1], [1,2], [2,3], [3,0],
    [4,5], [5,6], [6,7], [7,4],
    [0,4], [1,5], [2,6], [3,7]
]


def rot_matrix(roll, pitch, yaw=0.0):
    cr, sr = np.cos(roll), np.sin(roll)
    cp, sp = np.cos(pitch), np.sin(pitch)
    cy, sy = np.cos(yaw), np.sin(yaw)

    Rx = np.array([[1, 0, 0],
                   [0, cr, -sr],
                   [0, sr,  cr]])
    Ry = np.array([[ cp, 0, sp],
                   [  0, 1,  0],
                   [-sp, 0, cp]])
    Rz = np.array([[cy, -sy, 0],
                   [sy,  cy, 0],
                   [ 0,   0, 1]])
    return Rz @ Ry @ Rx

def get_vertices(roll, pitch):
    return base_vertices @ rot_matrix(roll, pitch).T

def set_axes_equal(ax, lim=5.0):
    ax.set_xlim(-lim, lim)
    ax.set_ylim(-lim, lim)
    ax.set_zlim(-lim, lim)
    try:
        ax.set_box_aspect([1, 1, 1])
    except Exception:
        pass


fig = plt.figure(figsize=(7, 6))
ax = fig.add_subplot(111, projection='3d')
ax.set_title("Orientation Temps Réel - ADXL345", pad=12)
ax.set_xlabel("X")
ax.set_ylabel("Y")
ax.set_zlabel("Z")
ax.grid(True)
set_axes_equal(ax)


init_verts = get_vertices(0.0, 0.0)
poly3d = [[init_verts[i] for i in face] for face in faces_idx]

board = Poly3DCollection(
    poly3d,
    linewidths=1.8,
    edgecolor=(0.05, 0.15, 0.5),
    facecolor=(0.10, 0.35, 0.90)
)
ax.add_collection3d(board)

dummy_segs = [((0, 0, 0), (0, 0, 0))]
edge_lines = Line3DCollection(
    dummy_segs,
    linewidths=2.5,
    colors=(0.02, 0.05, 0.25)
)
ax.add_collection3d(edge_lines)

axis_len = 3.0
axisX, = ax.plot([0, axis_len], [0, 0], [0, 0], lw=2, c="r")
axisY, = ax.plot([0, 0], [0, axis_len], [0, 0], lw=2, c="g")
axisZ, = ax.plot([0, 0], [0, 0], [0, axis_len], lw=2, c="b")

txt = ax.text2D(0.02, 0.95, "", transform=ax.transAxes)


last_sample = None

def read_latest_packet():
    global last_sample
    while True:
        try:
            data, _ = sock.recvfrom(1024)
        except BlockingIOError:
            break
        if len(data) >= 6:
            last_sample = data[:6]

def compute_roll_pitch_from_adxl(raw6):
    rx, ry, rz = struct.unpack("!hhh", raw6)
    ax_g = rx * 0.0039
    ay_g = ry * 0.0039
    az_g = rz * 0.0039

    roll  = np.arctan2(ay_g, az_g)
    pitch = np.arctan2(-ax_g, np.sqrt(ay_g**2 + az_g**2))
    return roll, pitch, ax_g, ay_g, az_g


def update(_):
    read_latest_packet()

    if last_sample is None:
        return board, edge_lines, axisX, axisY, axisZ, txt

    roll, pitch, axg, ayg, azg = compute_roll_pitch_from_adxl(last_sample)

    roll  *= SENSITIVITY
    pitch *= SENSITIVITY

    verts = get_vertices(roll, pitch)

    board.set_verts([[verts[i] for i in face] for face in faces_idx])

    board.set_facecolor([
        (0.05, 0.22, 0.60),  # bottom
        (0.15, 0.50, 1.00),  # top
        (0.10, 0.35, 0.90),
        (0.10, 0.35, 0.90),
        (0.10, 0.35, 0.90),
        (0.10, 0.35, 0.90),
    ])

    edge_lines.set_segments([(verts[i], verts[j]) for i, j in edges_idx])

    R = rot_matrix(roll, pitch)
    ex = R @ np.array([axis_len, 0, 0])
    ey = R @ np.array([0, axis_len, 0])
    ez = R @ np.array([0, 0, axis_len])

    axisX.set_data([0, ex[0]], [0, ex[1]])
    axisX.set_3d_properties([0, ex[2]])
    axisY.set_data([0, ey[0]], [0, ey[1]])
    axisY.set_3d_properties([0, ey[2]])
    axisZ.set_data([0, ez[0]], [0, ez[1]])
    axisZ.set_3d_properties([0, ez[2]])

    txt.set_text(
        f"a = ({axg:+.2f}, {ayg:+.2f}, {azg:+.2f}) g"
    )

    return board, edge_lines, axisX, axisY, axisZ, txt

ani = FuncAnimation(fig, update, interval=30, blit=False)
plt.show()
