import 'package:flutter/material.dart';

class SkeletonLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Duration duration;
  
  const SkeletonLoading({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutSine,
    ));
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + _animation.value, 0.0),
              end: Alignment(_animation.value, 0.0),
            ),
          ),
        );
      },
    );
  }
}

class ToyCardSkeleton extends StatelessWidget {
  final double cardWidth;
  
  const ToyCardSkeleton({
    Key? key,
    this.cardWidth = 160,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoading(
            width: cardWidth,
            height: cardWidth * 1.2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoading(
                  width: cardWidth * 0.7,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                SkeletonLoading(
                  width: cardWidth * 0.5,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SkeletonLoading(
                      width: cardWidth * 0.3,
                      height: 18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const Spacer(),
                    SkeletonLoading(
                      width: 24,
                      height: 24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomePageSkeleton extends StatelessWidget {
  const HomePageSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Search bar skeleton
            Padding(
              padding: const EdgeInsets.all(16),
              child: SkeletonLoading(
                width: double.infinity,
                height: 48,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            // Grid skeleton
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return const ToyCardSkeleton();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePageSkeleton extends StatelessWidget {
  const ProfilePageSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header skeleton
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Row(
                children: [
                  const SkeletonLoading(
                    width: 100,
                    height: 100,
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                  const SizedBox(width: 72),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoading(
                        width: 120,
                        height: 22,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoading(
                        width: 80,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Stats cards skeleton
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLoading(
                            width: 24,
                            height: 24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          SkeletonLoading(
                            width: 60,
                            height: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 4),
                          SkeletonLoading(
                            width: 40,
                            height: 24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLoading(
                            width: 24,
                            height: 24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          SkeletonLoading(
                            width: 60,
                            height: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 4),
                          SkeletonLoading(
                            width: 50,
                            height: 24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Collection grid skeleton
            Container(
              height: 300,
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  return SkeletonLoading(
                    width: 60,
                    height: 60,
                    borderRadius: BorderRadius.circular(8),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}