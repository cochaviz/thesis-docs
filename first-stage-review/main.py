from manim import *
# from manim_slides import Slide

def construct_text_slide(scene, title_text, subtitle_text, bullet_points):
        elements = VGroup()

        if title_text:
            title = Text(title_text, font_size=48).to_edge(UP)
            elements.add(title)
        else:
            title = None

        if subtitle_text:
            subtitle = Text(subtitle_text, font_size=32)
            if title:
                subtitle.next_to(title, DOWN)
            else:
                subtitle.to_edge(UP)
            elements.add(subtitle)

        if bullet_points:
            bullets = BulletedList(
                *bullet_points,
                font_size=28,
                buff=0.2,
            )
            if elements:
                bullets.next_to(elements, DOWN, aligned_edge=LEFT, buff=1)
            else:
                bullets.to_edge(LEFT)
            elements.add(bullets)

        # Center whole slide vertically a bit down from exact center
        elements.move_to(ORIGIN).shift(0.5 * UP + 0.5 * LEFT)

        # Very simple animation for now
        scene.play(FadeIn(elements, lag_ratio=0.1))
        scene.wait()


# --- Individual slides ----------------------------------------------------

class TitleSlide(Scene):
    def construct(self):
        title = Text("Botnet in a bottle", font_size=60)
        name = Text("Zohar Cochavi", font_size=32).next_to(title, DOWN)
        subtitle = Text(
            "Toward a consolidated botnet analysis pipeline",
            font_size=28,
        ).next_to(name, DOWN)

        # group = VGroup(title, name, subtitle).move_to(ORIGIN)

        self.play(Write(title))
        self.play(FadeIn(name, shift=DOWN))
        self.play(FadeIn(subtitle, shift=DOWN))
        self.wait()


class IntroductionMotivation(Scene):
    def construct(self) -> None:
        title_text = "Introduction"
        subtitle_text = "Motivation"
        bullet_points = [
            "Botnets can have massive impact",
            "Understanding:",
            "   Who is targeted",
            "   How they are targeted",
            "Can aid detection and response to improve overall security",
        ]

        construct_text_slide(
            self,
            title_text,
            subtitle_text,
            bullet_points
        )


class IntroductionCurrentApproach(Scene):
    title_text = "Introduction"
    subtitle_text = "Current Approach"
    bullet_points = [
        "This intelligence can be extracted from C2 traffic",
        "Requires manual reverse-engineering",
        "Delayed response (high turnover rate of C2 servers)",
        "Lack of scalability (large number of active botnets)",
    ]


class IntroductionProposedSolution(Scene):
    title_text = "Introduction"
    subtitle_text = "Proposed Solution"
    bullet_points = [
        "We are interested in network traffic",
        "Lean in to this:",
        "• Let the malware talk with the C2",
        "• Block other flows to avoid impact",
        "• Monitor network for interesting behavior",
        "Result: run many samples for a long period of time",
    ]


class ResearchQuestionMain(Scene):
    title_text = "Research Question"
    subtitle_text = "Main Question"
    bullet_points = [
        "How can we infer IoT botnet DDoS attack targets,",
        "DDoS attack methods, infection targets, and infection methods",
        "from sandboxed network traffic alone while restricting",
        "allowed communications to the C2 server?",
    ]


class ResearchQuestionSub1(Scene):
    title_text = "Research Question"
    subtitle_text = "Subquestion 1"
    bullet_points = [
        "How can we allow just C2 network traffic",
        "while capturing and sinkholing non-C2 traffic",
        "to avoid collateral damage?",
    ]


class ResearchQuestionSub2(Scene):
    title_text = "Research Question"
    subtitle_text = "Subquestion 2"
    bullet_points = [
        "What traffic features (flow metadata, timing/periodicity,",
        "header semantics, inter-flow correlations) best distinguish",
        "common IoT DDoS attack types?",
    ]


class ResearchQuestionSub3(Scene):
    title_text = "Research Question"
    subtitle_text = "Subquestion 3"
    bullet_points = [
        "How accurate is DDoS attack target",
        "and DDoS attack kind extraction?",
    ]


class ResearchQuestionSub4(Scene):
    title_text = "Research Question"
    subtitle_text = "Subquestion 4"
    bullet_points = [
        "What features distinguish spreading behavior",
        "from DDoS attacking behavior?",
    ]


class CurrentSituationImplemented(Scene):
    title_text = "Current Situation"
    subtitle_text = "Implemented Solution"
    bullet_points = [
        "At the current stage, the experimental setup is as follows:",
        "• Isolation (bottled): QEMU VMs on an isolated network",
        "• Monitoring (botmon): network analysis tool extracting",
        "  network traffic based on particular behavior",
        "• Orchestration (bottle): orchestrator and analysis process",
        "  which terminates analyses based on (lack of) events",
    ]


class CurrentSituationAnalysisFlow(Scene):
    title_text = "Current Situation"
    subtitle_text = "Analysis Flow"
    bullet_points = [
        "1. Determine C2 Address",
        "   1. Run sample in complete isolation",
        "   2. Monitor outgoing IPs, saving ‘interesting’ ones",
        "      as candidates",
        "2. Monitor bot behavior",
        "   1. Allow communication with candidate",
        "   2. Monitor for high packet-rate / beaconing activity",
        "   3. Disable if t time has passed since last",
        "      interesting event",
    ]


class ProgressHowWeGotHere(Scene):
    title_text = "Progress Overview"
    subtitle_text = "How We Got Here"
    bullet_points = [
        "Week 1–2: Literature review and start on sandbox",
        "Week 2–3: First results running in complete isolation",
        "Week 4–5: Getting completely side-tracked with software engineering",
        "Week 6–7: The discovery of ducktape",
        "Week 8–9: Incident and first attacks",
        "Week 10–12: Scaling up",
        "Week 12–14: Just running stuff",
    ]


class ProgressLessonsLearned(Scene):
    title_text = "Progress Overview"
    subtitle_text = "Lessons Learned"
    bullet_points = [
        "Engineering:",
        "• Ducktape is a virtue (to some extent)",
        "• Don’t be afraid to throw stuff away",
        "",
        "Research:",
        "• You can’t plan everything",
        "• Genuinely try to verify",
    ]


class PreliminaryResults(Scene):
    title_text = "Preliminary Results"
    subtitle_text = "Open Discussion"
    bullet_points = []

class TwoStageAnalaysisDescription(Scene):
    def construct(self):
        stage_one = Text("1. Retrieve C2 server address candidates") 
        stage_two = Text("2. Allow C2 traffic, and monitor behavior").next_to(stage_one, DOWN * 1.5)

        VGroup(stage_one, stage_two).center()

        self.play(Write(stage_one))
        self.play(Write(stage_two))

class TwoStageAnalaysisStageOne(Scene):
    @staticmethod
    def boxed_thing(thing, buff=.5, surround_with=Square):
        thing_box = surround_with().surround(thing, buff=buff)
        boxed_thing = VGroup(thing, thing_box)

        return thing, thing_box, boxed_thing
        

    def construct(self):
        bug = SVGMobject("assets/bug.svg")          # put bug.svg next to your .py, or give a path
        bug.set_stroke(
            color=RED,
            width=6,
        )
        bug.scale(.4)

        for obj in bug:
            obj.cap_style = CapStyleType.ROUND

        bug.move_to(ORIGIN)

        self.play(Write(bug))
        self.wait()

        _, bug_box, boxed_bug = self.boxed_thing(bug) 

        self.play(Write(bug_box))
        self.wait()

        self.play(
            boxed_bug.animate.to_edge(LEFT, buff=.5)
        )

        br_vm, br_vm_box, boxed_br_vm = self.boxed_thing(MathTex("br_{vm}"))
        boxed_br_vm.move_to(LEFT)

        flow_vm = DoubleArrow(
            boxed_bug.get_right(),
            br_vm_box.get_left(),
        )
        
        self.play(
            Write(flow_vm),
            Write(br_vm),
            Write(br_vm_box)
        )
        self.wait()

        br_inet, br_inet_box, boxed_br_inet = self.boxed_thing(MathTex("br_{inet}"))
        boxed_br_inet.scale(.9)
        br_www = MathTex("br_{www}", color=RED)

        boxed_br_inet.to_corner(UR, buff=.5)
        br_www.to_corner(DR, buff=.5)

        self.play(
            Write(boxed_br_inet), 
        )
        self.play(
            Write(br_www)
        )

        flow_inet = DoubleArrow(
            br_vm_box.get_right(),
            br_inet_box.get_left()
        )

        self.play(
            Write(flow_inet),
        )

        flow_www = DoubleArrow(
            br_vm_box.get_right(),
            br_www.get_left()
        )        

        self.play(
            Write(flow_www),
        )

        no_conn_to_www = Cross(flow_www, color=RED, scale_factor=.5)
        self.play(
            Write(no_conn_to_www)
        )
        self.wait()

        self.play(
           FadeOut(no_conn_to_www, flow_www, br_www) 
        )

        def arrow_follow_updater(arrow, a, b):
            arrow.put_start_and_end_on(a.get_right(), b.get_left())

        follow_vm_flow = lambda arrow: arrow_follow_updater(arrow, bug_box, br_vm_box)
        follow_inet_flow = lambda arrow: arrow_follow_updater(arrow, br_vm_box, br_inet_box)

        flow_vm.add_updater(follow_vm_flow)
        flow_inet.add_updater(follow_inet_flow)

        self.play(
            boxed_bug.animate.to_corner(UL),
            boxed_br_vm.animate.center().to_edge(UP),
        )

        flow_vm.remove_updater(follow_vm_flow)
        flow_inet.remove_updater(follow_inet_flow)


        for _ in range(5):
            packet = Dot(flow_vm.get_start(), color=YELLOW)
            self.play(MoveAlongPath(packet, flow_vm))
            self.play(MoveAlongPath(packet, flow_inet))
            self.play(MoveAlongPath(packet, flow_inet.reverse_direction()))
            self.play(MoveAlongPath(packet, flow_vm.reverse_direction()))

            flow_inet.reverse_direction()
            flow_vm.reverse_direction()