"""为全部 GDScript 生成中文 XML 文档注释，并检查声明覆盖率。"""
from pathlib import Path
import re
from html import escape
ROOT = Path(__file__).resolve().parents[1]
CLASS = {
'game_state': '游戏规则与存档模型。使用 RefCounted 自动管理内存；不依赖窗口、声音或三维场景，便于单独学习和测试。',
'main': '游戏流程控制器。连接规则模型、三维地图、界面和声音，把玩家输入转换为建造、回合、存档等操作。',
'world_view': '三维地图视图。负责正交相机、六边形地块、射线拾取、建筑实例、选中轮廓和建造预览。',
'model_factory': '程序化低多边形模型工厂。组合盒体、圆柱和三角屋顶，生成原创建筑与资源模型；静态缓存复用网格及材质。',
'building_visual': '可复用建筑视觉组件。kind 决定建筑种类；负责材料下落拼装、落地尘土以及建成后的循环动画。',
'resource_visual': '可复用资源视觉组件。根据 kind 创建金币、粮食、木材或石材模型，并提供轻微的展示动画。',
'audio_manager': '音效管理器。八个播放通道允许音效重叠，落地声采用节流避免过密，并支持音量和静音。',
'hud': '工业终端风格界面。构造资源栏、建筑卡片、地块检查器、菜单、设置和势力档案，通过信号向控制器报告操作。',
'faction_backdrop': '势力与菜单背景动效。用二维绘制 API 生成网格、扫描线与斜线，不拦截玩家点击。',
 'test_model': '无窗口规则测试入口。覆盖原版地图、建造限制、资源结算、撤销、饥荒及新旧存档兼容。失败时以非零状态退出。',
 'test_scene': '无窗口场景集成测试入口。验证真实场景中的界面流程、射线拾取、建筑与资源模型、动画及音效导入。'
}
VAR_TEXT = '''
CELL_RADIUS:六边形地块世界半径，扩大为 1.25 以提升模型可读性
WIDTH:地图列数，沿用原版的 23 列
HEIGHT:地图行数，沿用原版的 17 行
ORDER:可建建筑顺序，同时对应数字快捷键 1 到 6
RESOURCE_NAMES:资源内部键到中文名称的映射
TERRAIN_NAMES:地形内部键到中文名称的映射
COLORS:允许使用的势力配色列表
CATALOG:建筑规则表，含名称、费用、回合产出、人口增长和地形提示
BUILDING_SCENES:建筑类型到可复用 PackedScene 场景的映射
RESOURCE_SCENES:资源类型到可复用 PackedScene 场景的映射
GROUND_COLORS:不同地形的基础颜色
CLIPS:音效名称到 AudioStreamWAV 文件的映射
FACTIONS:四个原创势力的身份、旗帜标识、背景及颜色
INK:工业界面的最深背景色
PANEL:工业面板底色
LINE:面板细线与边框颜色
GOLD:关键操作和重点信息使用的金色
TEXT:主要文字颜色
MUTED:次要说明文字颜色
CYAN:选中、有效建造与收益提示颜色
SAVE_PATH:手动快速存档路径，user:// 表示 Godot 的用户数据目录
AUTO_PATH:自动存档路径，与手动存档分开保存
PREFS_PATH:音量、静音、动态效果和全屏偏好的配置路径
terrain:二维地形数组，通过 terrain[行][列] 读取内部地形键
buildings:以建筑锚点 Vector2i 为键的建筑记录字典
occupied:地块到所属建筑锚点的映射，使三格帐篷只结算一次收益
resources:当前四类资源数量，键为 gold、food、wood、stone
population:当前聚落人口，用于计算粮食消耗和增长
turn:当前回合数，从 1 开始
faction:当前势力的旗帜标识、名称、颜色和背景
journal:行动记录字符串数组，存档保留最近十五条
undo_stack:本回合建造快照栈，保存锚点、扣费前资源和日志长度
state:规则模型对象，作为游戏数据的唯一来源
hud:界面对象，负责展示数据和发出交互信号
world:三维地图对象，负责相机、模型和拾取
map_viewport:独立三维子视口，与界面点击区域分离
map_container:承载三维子视口的界面容器
file_dialog:导入或另存 JSON 的文件选择窗口
scene:当前流程状态，menu、factions、game、pause 或 settings
return_scene:进入设置前的流程状态，用于正确返回
session_started:是否已经建立或读取一个可继续的聚落
selected:点击固定的地块坐标
hovered:鼠标当前悬停的地块坐标，负坐标代表地图外
chosen:当前待建建筑类型，空字符串表示选择模式
rotation_value:当前建筑旋转档位，0 到 5 对应六个 60 度方向
dragging:是否正在通过鼠标拖动镜头
drag_distance:本次拖动累计像素距离，用于区分右键点击和拖动
right_down:当前拖动是否由右键启动
dynamic_effects:全局动态效果开关，控制建造、完工与界面动画
last_turn_msec:上次结束回合的毫秒时间，避免连续重复触发
last_hover_msec:上次射线悬停检测时间，降低不必要的检测频率
audio:管理合成音效的 BelfortAudio 对象
players:复用的音效播放通道数组
volume:线性音量，范围 0 到 1
muted:是否静音
last_impact:最近一次材料落地音效的时间，单位秒
materials:按颜色和金属度缓存的材质字典
mesh_cache:按形状及尺寸缓存的网格字典
kind:可在检查器中设置的建筑或资源内部类型
flag_color:该建筑使用的势力旗帜基础色
flag_texture:势力旗帜 SVG 对应的纹理资源
geometry:包含建筑或资源实际网格的子节点
animated_parts:需要在完工后持续运动的网格对象数组
animation_enabled:该对象的循环动画是否启用
constructing:是否仍处于材料下落拼装阶段
clock:动画累计时间，单位秒
construction_tween:负责并行下落、缩放和完成回调的 Tween 对象
rest_poses:动画部件到初始 Transform3D 的映射，用于恢复原姿态
camera:正交 Camera3D 对象，保持远近物体的屏幕大小一致
map_root:所有地块、装饰和已建建筑的父节点
selection_root:点击或悬停轮廓的父节点
preview_root:建造幽灵模型及有效性轮廓的父节点
building_nodes:建筑锚点到已实例化三维节点的映射
decoration_nodes:地块到树木、岩石等自然装饰节点的映射
hex_mesh:可复用的六边形厚地块网格
ring_mesh:可复用的六边形边框网格
focus:正交镜头在地图平面上的观察中心
zoom:当前正交相机尺寸，数值越小画面越近
target_zoom:镜头缩放的目标尺寸
yaw:相机当前水平朝向，单位弧度
target_yaw:相机水平转向的目标角度
preview_key:缓存上次预览参数，仅变化时重建幽灵模型
overlay:拦截地图操作的全屏菜单遮罩
overlay_panel:当前菜单的主要面板对象
resource_values:资源键到库存数值 Label 的映射
resource_deltas:资源键到下回合净变化 Label 的映射
build_buttons:建筑类型到建造卡片 Button 的映射
inspector_title:显示地形、建筑和坐标的标题标签
inspector_body:显示地块说明或建造预览的标签
inspector_yields:承载地块或建筑产出图标的横向容器
journal_label:显示最近行动记录的标签
notice_panel:始终位于界面最前方的操作反馈面板，确保菜单中的错误也可见
notice_label:显示短暂操作反馈的标签
notice_timer:控制操作反馈自动消失的一次性计时器
status_label:显示建造有效性、原因和方向的标签
turn_label:显示当前回合数的标签
faction_label:显示当前势力名称的标签
undo_button:撤销最近一次本回合建造的按钮
rotate_button:旋转当前待建建筑的按钮
next_button:结束回合的主要操作按钮
continuous:控制放置后是否继续保留建筑类型的复选框
faction_draft:势力选择中的临时数据，确认后才交给规则模型
faction_cards:四个势力选择卡片的按钮数组
faction_name:编辑势力名称的单行输入对象
faction_description:编辑势力背景的多行输入对象
filter_value:当前建筑分类过滤条件
selected_build:界面当前高亮的建筑类型
checks:当前测试已执行的检查数量
'''
LOCAL_TEXT = '''
a:当前六边形边或三角面的第一个顶点
b:当前六边形边或三角面的第二个顶点
action:当前待处理的操作标识或撤销快照
actions:排列确认与返回按钮的横向容器
after:相机缩放后鼠标对应的地图平面位置
anchor:建筑锚点坐标，即记录建筑的主地块
angle:当前圆周位置的弧度角
angle_a:当前六边形边起点的弧度角
angle_b:当前六边形边终点的弧度角
backdrop:绘制工业网格和扫描线的背景控件
banner:面向相机显示聚落名称的 Label3D
before:操作前的资源快照或鼠标对应地图位置
before_round:回合结算前的资源快照
before_undo:撤销测试中建造前的资源快照
begin:确认势力并建立聚落的按钮
blade:伐木场可旋转的锯片网格
bottom:底部地块检查与日志面板
building:当前遍历或查询到的建筑记录
building_anchor:占地格所属的建筑锚点
card:当前建筑或势力的按钮卡片
card_row:建筑卡片内部的图标与文字横向排列
cards:排列势力卡片的横向容器
cell:当前待查询、占用或绘制的地块坐标
cells:一座建筑覆盖的所有地块坐标数组
center:地图格中心位置或用于居中菜单的容器
checkbox:当前设置项对应的复选框
coin:资源模型中的一枚金币网格
collider:让地块能被物理射线命中的碰撞形状节点
color:当前模型或反馈状态使用的颜色
column:纵向排列界面元素的容器
command:是否按下 macOS Command 或其他平台 Ctrl 修饰键
config:读取和写入偏好的 ConfigFile 对象
connected:待建建筑是否接触已有聚落的标志
content:界面卡片或资源单元内的内容容器
controls:保存、读取和设置按钮的横向容器
cost_row:建筑费用图标的横向容器
damaged:测试中故意破坏字段的存档副本
dark:模型门洞、绳索等使用的深色
decoration:某个地块的自然装饰父节点
delay:材料或面板动画的延迟，单位秒
delta:本次帧间隔或当前资源的回合净变化
details:势力徽记与编辑字段的横向容器
direction:镜头移动方向、射线方向或帐篷方向档位
dust:单次落地尘土粒子组的父节点
emblem:当前势力徽记的 TextureRect
end:木材模型中的浅色切面网格
environment:控制背景、环境光和色调映射的 Environment 资源
environment_node:将环境资源加入三维世界的节点
error:规则或文件操作返回的错误说明
exported:从规则模型导出的可序列化存档字典
faces:屋顶三角面使用的顶点索引数组
factor:将屏幕拖动距离换算为世界距离的比例
fields:势力名称和背景编辑控件的纵向容器
file:当前打开的文件访问对象
filters:建筑分类按钮的横向容器
first:测试中用于观察运动的第一个动画网格
flag:市政厅旗帜对应的网格对象
flag_material:带势力旗帜图案的独立材质
font:支持中文系统字体回退的 SystemFont 对象
forward:相机在地图平面上的前后方向单位向量
found:是否找到旧版帐篷的两格附属占地
 gain:本回合各资源净收益及人口增长信息
game:集成测试中的真实游戏控制器实例
gear:工坊可旋转的齿轮网格
ghost:尚未建造的半透明建筑模型
ghost_material:表示可建或不可建状态的半透明材质
glow:用于让地块轮廓清晰可见的不受光材质
grid_color:背景网格线的低透明度颜色
ground:当前地块的地形内部标识
group:一座多格建筑或一组模型的父节点
header:顶部资源与回合面板
height:当前模型高度
hint:地图上方的镜头操作提示标签
hit:物理射线的碰撞结果字典
income:用于预览或核对的回合收入字典
index:当前循环中的序号，从 0 开始
info:当前建筑、势力或存档字段的详细信息
initial:动画测试中变化前的姿态
inspection:底部地块信息的纵向容器
instance:新建的 MeshInstance3D 网格实例
key:字典字段、缓存键或当前设置名称
label:当前网格节点名称，用来区分旗帜、作物和机械
legacy:转换为原版 v0.6 格式的测试存档
legacy_parts:旧版存档中尚未归属到帐篷的 tent_part 地块
list:纵向排列建筑卡片的容器
loaded:用于验证存档导入结果的独立规则模型
local:鼠标相对地图容器左上角的二维位置
low_a:六边形边起点对应的底面顶点
low_b:六边形边终点对应的底面顶点
map_frame:包裹地图视口的工业风边框面板
margin:控制卡片内容内边距的容器
menu_button:顶部暂停按钮
mesh:可复用的网格几何资源
missing:资源不足的中文原因列表
name_value:地块检查器中显示的建筑名称
normals:地块网格的法线数组，用于检查顶面朝向
now:当前引擎运行时间，用于节流或防连击
 offset:当前三角面内部的顶点索引偏移
 offsets:六边形邻格的坐标偏移数组
origin:射线起点或测试中的市政厅坐标
parse_error:JSON 语法解析返回的错误码
parser:负责检测 JSON 格式的解析对象
parts:当前建筑的顶层材料网格列表
path:本次读写的完整文件路径
pieces:当前建筑产出说明的文字片段数组
player:当前被选中的 AudioStreamPlayer 通道
point:射线投影坐标或模型局部位置
pointer:换算到三维子视口像素坐标的鼠标位置
points:构造凸六边形碰撞体的顶点数组
position_3d:地块中心加上地形高差后的三维位置
previous:临时修改前的原始资源快照
prop:摆放在建筑旁的资源模型实例
puff:单个落地尘土方块
query:物理射线查询参数
random:只用于装饰外观的独立随机数生成器，不改变游戏规则
record:一条建筑或存档记录
records:供 JSON 序列化的建筑记录数组
red:屋顶使用的砖红色
resource:当前测试的资源模型实例
resource_type:当前资源模型的内部类型
resource_types:建筑类型到其周边可展示资源种类的映射
rest:动画部件的初始变换
result:当前函数构造并最终返回的对象、数值或结果字典
right:相机在地图平面上的左右方向单位向量
ring:围绕锚点排列的六个邻格或测试轮廓网格
ring_normals:建造预览轮廓的法线数组
rock:低多边形石块或丘陵装饰网格
root:程序化模型的根节点
row:横向界面容器或当前地形行
scan_y:随时间向下移动的扫描线纵坐标
scroll:使建筑卡片在较小窗口中仍可访问的滚动容器
seen:测试中已出现的帐篷旋转签名数组
selected:该卡片是否处于选中状态
shade:菜单全屏深色遮罩
shape:地块六边形凸碰撞资源
shortage:某项建造费用仍缺少的数量或合并说明
sidebar:右侧建造与回合控制面板
signature:足迹坐标序列的字符串，用于检测方向是否重复
slider:调节线性音量的滑杆
snapshot:载入失败前的完整状态字符串快照
staged:只用于验证存档的临时规则模型，验证成功后再整体替换
starving:当前回合是否发生粮食不足的标志或结算结果
stem:麦穗模型中的茎秆位置
stone:墙体和基础使用的浅石材颜色
stopped:关闭动画后的固定姿态快照
sun:提供方向光和阴影的太阳光节点
surface:逐顶点构造三角形网格的 SurfaceTool 对象
tab:建筑分类筛选按钮
target:动画最终位置或找到的合法建筑地块
teal:机械棚顶使用的灰绿色
tile_nodes:每个地块坐标到独立 StaticBody3D 对象的映射
farm_cell:通过实际地图输入测试放置农场的目标地块
farm_point:农场目标格投影到三维子视口后的坐标
click_event:模拟玩家左键点击的 InputEventMouseButton 事件
wood_before:通过界面建造前的木材数量快照
screen_point:测试地块中心投影到屏幕后的二维坐标
zoom_pointer:测试以鼠标位置为中心缩放的子视口坐标
zoom_anchor:缩放开始前鼠标指向的世界平面位置
pressed_tile:集成测试中被点击的独立六边形地块对象
resting_y:测试中地块点击前的原始高度
base_y:点击反馈开始前的静止高度，重复点击时避免累积下沉
previous_tween:该物体上一次点击反馈 Tween，用于取消尚未结束的下压
node:需要播放下压和回弹的三维对象
tile:同时承载六边形显示与碰撞的 StaticBody3D 节点
timber:木梁、支柱和台面使用的木材颜色
timber_log:水平摆放的木料圆柱网格
tools:旋转与撤销按钮的横向容器
tooth:锯片边缘的小齿网格
towns:存档中的市政厅数量，合法存档必须恰好为一座
turn_box:顶部回合图标与数值的横向容器
tween:控制本次属性插值或回调时序的 Tween 对象
type:建筑或资源的内部类型字符串
ui_theme:统一工业风按钮、面板和字体的 Theme 资源
unchanged:失败建造前的序列化状态，用于检查无副作用
valid:当前地块是否满足全部建造规则
value:当前显示、保存或应用的参数值
vertices:程序化屋顶的基础顶点数组
visual:一座建筑的 BelfortBuildingVisual 实例
visuals:集成测试中需要检查的所有建筑实例
wordmark:顶部游戏名称与势力副标题容器
x:当前列坐标或模型半宽
z:模型在前后方向的半深度
'''
VARS={}
for block in (VAR_TEXT,LOCAL_TEXT):
 for line in block.strip().splitlines():
  key,val=line.strip().split(':',1);VARS[key]=val
FUNCTION_TEXT = '''
reset|重置地图、建筑和经济为原版初始状态，保留已选择的势力身份。|无返回值；修改当前模型并清空本回合撤销记录。
in_bounds|判断二维地块坐标是否位于 23×17 地图内。|布尔值，true 表示地图内，false 表示地图外。
cell_position|将奇数行错位六边形坐标换算为世界 XZ 平面位置。|Vector3 世界坐标；Y 固定为 0，实际地形高差由视图添加。
neighbors|按顺时针返回六个邻格坐标，保留地图外坐标以便边界验证。|包含六个 Vector2i 的数组。
footprint|根据建筑类型和六方向档位计算全部占地；帐篷为相邻三格。|Vector2i 数组，第一格始终是建筑锚点。
terrain_at|读取地块地形，地图外统一按水域处理。|grass、forest、hill 或 water 地形标识。
building_at|由任意占地格找到完整建筑，而不把帐篷附属格当成独立建筑。|建筑字典，包含 type、rotation、cells；空地返回空字典。
missing_cost|比较当前资源与建筑费用，汇总短缺的资源数量。|中文短缺说明；资源足够时返回空字符串。
placement_error|依次校验建筑种类、边界、占用、地形、连接关系和费用。|空字符串表示可建造；非空字符串解释第一个失败原因。
_register|登记建筑锚点与占地所有权，不扣除资源；供初始化和载入内部使用。|无返回值；更新 buildings 与 occupied 两张表。
place|执行一次经过完整校验的建造，保存撤销快照后扣费并登记占地。|空字符串表示成功；失败返回原因且不修改游戏状态。
undo|撤销本回合最近一次建造并精确退还资源。|被撤销的锚点坐标；没有可撤销操作时返回 (-1, -1)。
income|计算下回合资源净变化、食物消耗及可增长人口，不修改库存。|字典，包含 gold、food、wood、stone、population、consumption。
next_turn|结算建筑产出、人口粮食消耗和增长，推进回合并清空撤销栈。|包含 gain 和 starving 的字典；starving 表示是否因缺粮停止增长。
to_data|把 Vector2i 键和占地转换成 JSON 可保存的数据结构。|包含版本、地图、建筑、资源、人口、回合、势力和日志的字典。
save_to|先写入临时文件，再原子重命名，降低中断导致存档损坏的风险。|Godot Error 错误码，OK 表示写入成功。
whole_number|安全验证载入的数值是否为有限整数且落在允许范围内。|布尔值；字符串、无穷数、非整数或越界值均返回 false。
load_data|在临时模型中校验完整存档，并兼容原版 tent_part 格式；通过后整体提交。|成功返回空字符串；失败返回中文原因且当前游戏保持原状。
material|按颜色及金属度查找或创建共享三维材质。|可复用的 StandardMaterial3D 资源；调用者不应直接改动共享属性。
part|创建网格实例、赋予材质、加入父节点并设置局部位置。|已加入父节点的 MeshInstance3D 对象。
box|复用对应尺寸的 BoxMesh，创建木梁、墙体、台面等盒形部件。|已加入父节点的盒形 MeshInstance3D。
cylinder|创建低边数圆柱或圆锥，用于树木、金币、木料和机械部件。|已加入父节点的圆柱或圆锥 MeshInstance3D。
roof|按三角柱顶点构造屋顶，使用 Godot 顺时针三角形绕序。|已加入父节点的三角屋顶网格实例。
resource_model|组合基础几何体，生成指定资源的完整三维模型。|尚未加入场景树的 Node3D 根节点；调用者负责 add_child。
building|组合基础几何体，生成指定建筑的完整可拆分材料几何。|尚未加入场景树的 Geometry 根节点，内部部件有语义名称供动画识别。
_collect|递归查找需要循环运动的部件，并记录每个部件的初始姿态。|无返回值；填充 animated_parts 和 rest_poses。
construct|把实际建筑部件抬到空中，通过并行 Tween 依次落下拼成建筑。|无返回值；设置 constructing，完成后发出 construction_finished 信号。
_impact|发出材料落地信号，并生成短暂向外扩散的尘土方块。|无返回值；尘土动画结束后自动释放节点。
_finish|结束拼装阶段，允许持续动画并通知控制器播放完工音效。|无返回值；发出 construction_finished 信号。
set_dynamic|启用或关闭当前对象的持续动态效果，关闭时恢复静止姿态。|无返回值；三维地图版本会递归通知所有建筑与资源组件。
play|在空闲音效通道中播放指定提示，落地声受时间节流保护。|无返回值；静音、零音量或未知音效会直接忽略。
set_volume|限制并应用线性音量，将它换算成音频通道使用的分贝。|无返回值；修改音量并更新现有播放通道。
_update_camera|根据当前焦点、水平朝向和正交尺寸更新相机位置及朝向。|无返回值；相机继续观察地图平面的 focus。
home|将镜头恢复到市政厅附近的默认缩放与斜俯视角度。|无返回值；修改镜头目标焦点和目标角度。
pan|把屏幕方向的拖动换算成地图平面移动，并限制移动范围。|无返回值；改变镜头 focus。
zoom_at|围绕鼠标指向的地图位置缩放，减少缩放时地块漂移。|无返回值；更新相机尺寸和焦点，缩放限制在 10 到 60。
ground_point|将子视口鼠标位置投影到 Y=0 地图平面。|世界 Vector3；没有交点时使用当前镜头焦点。
pick|向三维世界发射物理射线，从命中地块的 metadata 中读取坐标。|命中的 Vector2i 地块；没有命中返回 (-1, -1)。
rebuild|从规则模型重建地图、装饰和建筑，用于新游戏或读取存档。|无返回值；旧地图节点释放，已有建筑不播放建造动画。
_clear|将某个父节点的全部子节点移出树并排队释放。|无返回值；父节点本身保留。
elevation|返回指定地形相对地图平面的高度差。|世界单位浮点数；丘陵略高，水面略低。
_create_tile|创建一个可拾取六边形地块，并按地形加入树木、岩石或水纹。|无返回值；将地块和装饰注册进地图节点。
_draw_river|复原原版沿共享六边形边界绘制的装饰河流。|无返回值；河流仅为视觉装饰，不引入额外可占用地块。
spawn_building|实例化规则模型中的建筑，在每个占地格放置建筑并隐藏自然装饰。|无返回值；按 animate 和动态开关决定是否播放材料下落。
_add_banner|在市政厅上方添加始终面向相机的聚落名称。|无返回值；将 Label3D 加入建筑父节点。
remove_building|移除撤销对应的建筑节点，并恢复已空出的自然装饰。|无返回值；规则数据应先由模型 undo 更新。
select|重建某格或其所属整座建筑的金色选中轮廓。|无返回值；无效坐标会清除选中显示。
preview|按地块、建筑、方向、资源和占地变化更新建造幽灵模型。|无返回值；有效位置用绿色，无效位置用红色，参数未变化时复用预览。
_override_ghost|递归替换预览网格材质，并关闭预览的投影。|无返回值；只作用于独立的幽灵模型实例。
_highlight|在指定地块上方生成一圈不受光照影响的彩色六边形轮廓。|无返回值；轮廓加入调用者提供的父节点。
_prism|通过 SurfaceTool 构造带厚度的六边形地块，顶面法线朝上。|ArrayMesh 网格资源，可被所有地图格复用。
_ring|构造略有宽度的六边形轮廓三角网格。|ArrayMesh 轮廓资源，顶面法线朝上。
style|创建方形工业面板的填色、边框与内容内边距样式。|StyleBoxFlat 资源，可赋给 PanelContainer 或 Button。
panel|创建使用统一工业风样式的面板并加入父节点。|PanelContainer 控件对象。
label|创建指定文字、字号和颜色的标签，默认不拦截鼠标。|Label 控件对象。
vbox|创建指定间隔的纵向布局容器。|已加入父节点的 VBoxContainer。
hbox|创建指定间隔的横向布局容器。|已加入父节点的 HBoxContainer。
icon|加载本地 SVG 并创建保持比例的图标控件。|TextureRect 控件，图像使用矢量资源导入。
button|创建不抢键盘焦点的按钮，按下时发出 action_requested 信号。|Button 控件对象；通过返回值继续设置样式或提示。
resource_pair|创建资源图标加数值的横向组合，并提供悬停名称。|数值对应的 Label，调用者可随后更新其 text。
_make_header|构建游戏名称、五个图标资源单元、回合数和暂停按钮。|无返回值；将库存与收益标签注册进字典。
_make_map|构建独立地图视口容器、镜头提示和短暂反馈标签。|无返回值；三维世界由控制器随后加入该容器。
_make_sidebar|构建分类、六种建造卡片、连续建造、撤销和回合按钮。|无返回值；建筑列表可滚动，较小窗口也能访问全部建筑。
_make_bottom|构建地块信息、产出图标和最近行动记录面板。|无返回值；保存相关标签引用以便后续刷新。
_make_overlay|创建全屏菜单根控件，菜单出现时拦截地图操作。|无返回值；初始遮罩隐藏。
_ignore_mouse|递归设置装饰控件为忽略鼠标，使卡片按钮完整接收点击。|无返回值；仅改变指定子树的 mouse_filter。
_filter|根据工业界面分类筛选显示的建筑卡片。|无返回值；更新卡片 visible 并报告点击动作。
_yield_text|把建筑的回合产出和人口增长转成中文悬停说明。|供 tooltip_text 使用的说明字符串。
refresh|刷新库存、净收益、回合、卡片高亮、撤销状态和建造提示。|无返回值；不重建三维地图，仅更新界面对象。
inspect|显示悬停或固定地块的信息，并解释当前建筑能否放置。|无返回值；更新标题、说明和回合产出图标。
_add_yields|将指定建筑的资源与人口产出添加为图标加数值。|无返回值；新控件加入 inspector_yields。
notify|展示短暂的成功或失败反馈，并启动自动隐藏计时。|无返回值；错误用暖红色，普通信息用浅金色。
_overlay_base|清理旧菜单，创建深色遮罩、扫描背景和居中面板。|面板内的 VBoxContainer，供具体菜单继续添加内容。
hide_overlay|隐藏菜单遮罩，将玩家操作交还地图。|无返回值；保留菜单节点供后续替换。
show_menu|构建主菜单，根据是否有存档或当前聚落显示继续入口。|无返回值；菜单按钮通过信号通知主控制器。
show_pause|构建暂停菜单，提供继续、保存、另存、设置和退出操作。|无返回值；显示全屏遮罩。
show_settings|构建音量、静音、动态效果、全屏设置与快捷键说明。|无返回值；修改控件时通过 setting_changed 报告参数。
show_factions|构建四势力旗帜卡片、徽记、名称和背景编辑界面。|无返回值；确认时发出 faction_confirmed，选择期间只修改草稿。
_choose_faction|把指定预设复制到势力草稿并更新编辑框与徽记。|无返回值；尚未修改正在运行的游戏规则模型。
_highlight_faction|根据草稿势力标识刷新四张势力卡片的选中边框。|无返回值；仅影响卡片样式。
_viewport_pointer|把界面逻辑坐标换算成子视口像素坐标，兼容窗口缩放。|用于相机射线投影的 Vector2。
_map_input|处理仅发生在地图区域的鼠标、拖动、滚轮和触控板手势。|无返回值；界面按钮事件不会进入这个处理器。
_map_exited|鼠标离开地图时清除幽灵预览并恢复固定地块信息。|无返回值；重置悬停坐标。
_update_hover|根据射线命中更新悬停地块、有效性预览和地块检查器。|无返回值；命中格未改变时直接返回以减少重绘。
_click_cell|选择地块；存在待建类型时请求模型建造，成功后同步三维世界。|无返回值；失败显示规则原因，成功按连续建造开关保留或清除类型。
_unhandled_key_input|处理快捷键；过滤自动重复，菜单和文本输入优先消费事件。|无返回值；Esc 按取消建造、暂停、返回的层级工作。
_choose|切换待建建筑类型并重置方向；再次选择同类型会取消。|无返回值；仅游戏状态可进入建造模式。
_cancel_build|取消建造模式和当前拖动，刷新预览与提示。|无返回值；不改变已经建成的建筑。
_refresh|将规则数据同步到界面、选中轮廓和建造预览。|无返回值；不重新创建整张地图。
_start_game|用已确认的势力建立新聚落，重置规则、镜头及交互状态。|无返回值；旧会话存在时先自动保存，保存失败则保留旧会话。
_show_menu|切换到主菜单并清除待建模式，保留当前会话以便继续。|无返回值；动态决定是否显示继续按钮。
_action|统一分派菜单、建造工具、存档和回合操作。|无返回值；回合操作有防连击，失败保存不会直接退出游戏。
_save|调用模型安全保存，并根据请求显示反馈及播放音效。|布尔值，true 表示成功，false 表示保存失败。
_load_file|读取和解析 JSON 后交给模型校验，成功后恢复三维世界与界面。|无返回值；语法或规则失败时保留当前游戏，最大接受 8 MiB 文件。
_open_file_dialog|打开导入或另存 JSON 窗口，并连接对应文件选择回调。|无返回值；文件窗口可见时地图快捷键暂不处理。
_setting|应用单个设置项，并立即保存偏好配置。|无返回值；支持音量、静音、动态效果和全屏。
_save_preferences|把声音与显示偏好写入用户数据目录。|无返回值；只保存设置，不保存地图进度。
_load_preferences|读取本地偏好并应用到声音、地图动画和显示模式。|无返回值；配置不存在时保留默认值。
_notification|接收系统关闭窗口通知，保存当前聚落和设置后再退出。|无返回值；存档失败时保留窗口，便于用户重试。
_initialize|测试脚本的 SceneTree 初始化入口，将测试延迟到场景树可用后执行。|无返回值；通过 call_deferred 调用 run。
check|累加检查次数；条件失败时记录错误并以非零状态结束。|无返回值；成功继续执行后续检查。
run|执行当前测试脚本中的规则或真实场景集成用例。|无返回值；全部通过时输出检查数并以状态 0 退出。
find_site|沿已有聚落寻找合法测试建造位置；按需调整测试地形。|合法 Vector2i 坐标；无可用位置返回 (-1, -1)。
find_site_ignoring_cost|暂时提供测试用木材寻找位置，然后恢复原资源。|用于资源不足测试的 Vector2i 地块坐标。
'''
FUNCTIONS={"press_cell":("让独立地块及其上已完工的建筑、资源和轮廓短暂下压再回弹。", "无返回值；关闭动态效果时保持静止，正在拼装的建筑不叠加点击动画。"), "_pulse_node":("取消旧的点击 Tween，从固定原始高度播放下压及回弹，避免连续点击导致地块越陷越深。", "无返回值；Tween 与目标节点绑定，目标释放时自动结束。"), "_exit_tree":("音频管理器退出场景树前停止播放并释放流引用，避免退出时残留播放对象。", "无返回值；由 Godot 在节点移出场景树时调用。") }
for line in FUNCTION_TEXT.strip().splitlines():
 name,summary,returns=line.split('|',2);FUNCTIONS[name]=(summary,returns)
READY={
'main':'引擎首次将主节点加入场景树后执行；创建并连接模型、界面、三维子视口、声音和信号，读取设置并显示主菜单。',
'world_view':'创建共享六边形网格、地图父节点、正交相机、太阳光与环境，准备接收规则数据。',
'hud':'创建支持中文的统一工业主题和各个主界面模块；由引擎在节点入树后调用。',
'building_visual':'按照 kind 生成建筑网格，应用势力旗帜，收集循环动画部件并记录初始姿态。',
'resource_visual':'按照 kind 创建资源模型并加入当前资源组件。',
'audio_manager':'创建八个可重叠播放的音效通道，供后续 play 调用复用。',
'faction_backdrop':'初始化背景控件，使其只负责绘制而不抢占鼠标事件。'}
PROCESS={
'main':'每帧处理 WASD 镜头平移，并以节流频率刷新镜头移动后的鼠标射线命中。菜单或文件对话框打开时不处理地图。',
'world_view':'每帧平滑插值相机缩放和朝向，再更新相机变换。',
'building_visual':'每帧根据部件名称更新完工建筑动画；材料拼装或关闭动态效果时暂停循环动画。',
'resource_visual':'每帧轻微转动金币或摇动粮食资源，木材与石材保持稳定。',
'faction_backdrop':'每帧推进扫描线时间并请求重绘，关闭动态效果时保持静止。'}
PARAMS={
 'node':'要播放点击反馈的 Node3D 对象。', 'cell':'要查询或操作的六边形坐标（列、行），从 0 开始。', 'anchor':'建筑主地块坐标，其余占地格归属于该锚点。',
 'type':'内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。', 'rotation':'六方向旋转档位，整数 0 到 5；每档为 60 度。',
 'rotation_value':'六方向旋转档位，整数 0 到 5；每档为 60 度。', 'cells':'该建筑需要占用的 Vector2i 地块数组，第一格为锚点。',
 'path':'待读写文件路径，可使用 user:// 或绝对路径。', 'data':'从 JSON 解析出的存档对象，使用前会进行完整校验。',
 'value':'要应用或检查的值；设置回调中的类型由 key 决定。', 'minimum':'允许的最小整数，包含此边界。', 'maximum':'允许的最大整数，包含此边界。',
 'color':'颜色值，使用 Godot Color，分量通常为 0 到 1。', 'metallic':'材质金属度，0 为非金属，1 为金属。',
 'parent':'接收新节点或需要递归处理的父节点。', 'mesh':'要显示的 Mesh 网格资源。', 'pos':'相对父节点的 Vector3 局部位置。',
 'label':'部件节点名称；动画系统依据这些语义名称识别部件。', 'size':'盒体或屋顶尺寸，使用世界单位。',
 'radius':'底部圆半径，使用世界单位。', 'height':'模型高度，使用世界单位。', 'top':'顶部圆半径；负数表示与底部半径相同，0 生成圆锥。',
 'flag_color':'市政厅旗帜的势力基础色。', 'enabled':'true 启用动态效果；false 停止并恢复静止姿态。',
 'delta':'本帧与上一帧的间隔秒数；镜头 pan 中则表示屏幕像素方向的移动量。',
 'cue':'音效内部键，如 click、land、build、turn、error、save、undo。', 'direction':'缩放方向或幅度，正数拉远，负数拉近。',
 'pointer':'相对三维子视口左上角的二维像素坐标。', 'new_state':'用于生成地图的完整 BelfortState 模型。',
 'animate':'是否播放建造拼装动画；读取存档时传 false。', 'group':'接收聚落名称标牌的建筑父节点。',
 'ghost_material':'用于显示绿色或红色半透明建筑的独立材质。', 'bottom':'六边形底面高度，单位为世界单位。',
 'fill':'面板底色，支持透明度。', 'border':'面板边框颜色。', 'width':'边框像素宽度；菜单基础方法中表示面板最小宽度。',
 'padding':'四边内容内边距，单位为逻辑像素。', 'caption':'控件显示的文本。', 'font_size':'文字字号。', 'separation':'相邻布局子控件的间隔像素数。',
 'key':'图标资源名、资源内部键或设置项内部名称，按调用方法决定。', 'pixels':'图标最小显示边长，单位为逻辑像素。',
 'action':'按钮或菜单操作标识，例如 save、pause、next_turn。', 'category':'建筑筛选分类，全部、生产或经济。',
 'state':'要展示或测试的规则模型。', 'chosen':'当前待建建筑类型；空字符串表示选择模式。',
 'message':'显示的中文反馈或测试失败说明。', 'is_error':'true 使用错误状态色；false 使用普通反馈色。',
 'has_save':'本地是否存在手动或自动存档。', 'has_session':'是否已有可继续的当前游戏会话。',
 'volume':'线性音量，范围 0 到 1。', 'muted':'当前是否静音。', 'effects':'当前是否启用动态效果。',
 'fullscreen':'当前是否使用全屏窗口。', 'current':'当前势力数据，用于初始化选择草稿。', 'index':'数组索引，从 0 开始。',
 'local':'鼠标相对地图容器左上角的界面逻辑坐标。', 'event':'引擎传入的输入事件，可包含按键、鼠标或触控板信息。',
 'faction':'玩家已确认的势力字典，包含 id、name、color、description。', 'feedback':'保存成功后是否显示提示和播放音效。',
 'saving':'true 打开保存窗口；false 打开读取窗口。', 'what':'Godot 引擎发送的通知常量。',
 'condition':'本次检查应满足的布尔表达式。'}
SIGNALS={
 'material_landed':'某批材料落地时发出；监听者播放经节流处理的落地音效。',
 'construction_finished':'建筑材料全部落定并结束拼装时发出；监听者播放完工音效。',
 'building_finished':'地图中一座新建筑完成拼装时发出，供主控制器播放声音。',
 'action_requested':'界面请求执行命名操作；action 为 save、pause、next_turn 等字符串。',
 'build_requested':'玩家选择建造卡片时发出；type 为六种可建建筑的内部键。',
 'faction_confirmed':'玩家确认势力草稿时发出；faction 包含旗帜标识、名称、配色和背景。',
 'setting_changed':'玩家修改设置时发出；key 指定设置名称，value 提供新值。'}

def split_params(text):
 result=[];start=depth=0;quote=None
 for i,c in enumerate(text):
  if quote:
   if c==quote and (i==0 or text[i-1]!='\\'):quote=None
  elif c in '\"\'':quote=c
  elif c in '([{':depth+=1
  elif c in ')]}':depth-=1
  elif c==',' and depth==0:result.append(text[start:i]);start=i+1
 if text[start:].strip():result.append(text[start:])
 return result

def xml(indent,tag,text,attrs=''):
 return f'{indent}## <{tag}{attrs}>{escape(text)}</{tag}>'

counts={'classes':0,'methods':0,'variables':0,'signals':0}
for path in sorted(ROOT.rglob('*.gd')):
 lines=[l for l in path.read_text().splitlines() if not l.lstrip().startswith('##')]
 out=[xml('', 'summary', CLASS[path.stem]),xml('', 'remarks','GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。')]
 counts['classes']+=1
 for line in lines:
  fm=re.match(r'(\s*)(?:static )?func (\w+)\((.*)\)(?:\s*->\s*([^:]+))?:',line)
  vm=re.match(r'(\s*)(?:@export(?:_enum)?(?:\(.*\))?\s+)?(?:static\s+)?(?:var|const)\s+(\w+)',line)
  sm=re.match(r'(\s*)signal\s+(\w+)(?:\((.*)\))?',line)
  if fm:
   indent,name,args,returns_type=fm.groups()
   if name=='_ready':summary=READY[path.stem];returns='无返回值；由 Godot 场景树生命周期自动调用。'
   elif name=='_process':summary=PROCESS[path.stem];returns='无返回值；修改显示或交互状态，不推进游戏回合。'
   elif name=='_draw':summary='使用 CanvasItem 绘图 API 画出工业网格、扫描线和斜线。';returns='无返回值；由引擎在 queue_redraw 后调用。'
   else:summary,returns=FUNCTIONS[name]
   out.append(xml(indent,'summary',summary))
   for raw in split_params(args):
    param=raw.strip().split(':')[0].split('=')[0].strip()
    assert param in PARAMS, (path,param)
    out.append(xml(indent,'param',PARAMS[param],f' name="{param}"'))
   out.append(xml(indent,'returns',returns))
   counts['methods']+=1
  elif vm:
   indent,name=vm.groups()
   assert name in VARS,(path,name)
   out.append(xml(indent,'summary',VARS[name]+'。'))
   counts['variables']+=1
  elif sm:
   indent,name,args=sm.groups();out.append(xml(indent,'summary',SIGNALS[name]))
   for raw in split_params(args or ''):
    param=raw.strip().split(':')[0];out.append(xml(indent,'param',PARAMS[param],f' name="{param}"'))
   counts['signals']+=1
  elif re.search(r'\bfunc\(', line):
   indent = re.match(r'\s*', line).group()
   callback = re.search(r'func\(([^)]*)\)', line)
   summary = '信号触发后执行局部回调，将当前控件或动画事件转发给所属系统。'
   if 'setting_changed.emit' in line: summary = '设置控件变化时，携带设置名称和新值通知主控制器。'
   elif 'action_requested.emit' in line: summary = '按钮被按下时，将绑定的操作标识发送给主控制器。'
   elif 'material_landed.emit' in line: summary = '将建筑材料落地事件转发为地图级信号。'
   elif 'building_finished.emit' in line: summary = '将建筑完工事件转发为地图级信号。'
   elif 'audio.play' in line: summary = '三维动画事件到达时播放对应的材料落地或建筑完工音效。'
   elif 'notice_panel.visible' in line: summary = '通知计时结束后隐藏反馈面板。'
   elif 'faction_draft.name' in line or line.rstrip().endswith('func():'): summary = '确认势力时整理名称和背景，再将势力草稿提交给主控制器。'
   out.append(xml(indent, 'summary', summary))
   for raw in split_params(callback.group(1)):
    param = raw.strip().split(':')[0]
    out.append(xml(indent,'param',PARAMS[param],f' name="{param}"'))
   out.append(xml(indent, 'returns', '无返回值；通过信号或对象属性产生效果。'))
   counts['methods'] += 1
  out.append(line)
 path.write_text('\n'.join(out)+'\n')
print('XML documentation coverage:',counts)
