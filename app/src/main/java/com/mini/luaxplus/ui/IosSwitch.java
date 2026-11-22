package com.mini.luaxplus.ui;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.widget.CompoundButton;

/**
 * iOS 风格的开关：胶囊轨道、圆形滑块、切换时有短促位移动画。
 * 继承 CompoundButton，保留 isChecked / setOnCheckedChangeListener 等原生用法。
 */
public class IosSwitch extends CompoundButton {

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF track = new RectF();
    private float progress = 0f;
    private boolean attached = false;
    private ValueAnimator animator;
    private int trackOff = 0xFFE9E9EB;
    private int trackOn = 0xFF34C759;

    public IosSwitch(Context context) {
        super(context);
        init();
    }

    public IosSwitch(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public IosSwitch(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        setButtonDrawable(null);
        setBackground(null);
        setFocusable(true);
        setClickable(true);
        setLayerType(LAYER_TYPE_SOFTWARE, null);
    }

    public void setTrackColors(int offColor, int onColor) {
        trackOff = offColor;
        trackOn = onColor;
        invalidate();
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int width = resolveSize(dp(51), widthMeasureSpec);
        int height = resolveSize(dp(31), heightMeasureSpec);
        setMeasuredDimension(width, height);
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        attached = true;
        progress = isChecked() ? 1f : 0f;
        invalidate();
    }

    @Override
    protected void onDetachedFromWindow() {
        attached = false;
        if (animator != null) {
            animator.cancel();
        }
        super.onDetachedFromWindow();
    }

    @Override
    public void setChecked(boolean checked) {
        boolean changed = isChecked() != checked;
        super.setChecked(checked);
        if (!attached) {
            progress = checked ? 1f : 0f;
            invalidate();
            return;
        }
        if (changed) {
            animateTo(checked ? 1f : 0f);
        }
    }

    private void animateTo(float target) {
        if (animator != null) {
            animator.cancel();
        }
        animator = ValueAnimator.ofFloat(progress, target);
        animator.setDuration(180);
        animator.addUpdateListener(new ValueAnimator.AnimatorUpdateListener() {
            @Override
            public void onAnimationUpdate(ValueAnimator animation) {
                progress = (float) animation.getAnimatedValue();
                invalidate();
            }
        });
        animator.start();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        float width = getWidth();
        float height = getHeight();
        float radius = height / 2f;
        track.set(0, 0, width, height);

        int off = trackOff;
        int on = trackOn;
        int color = Color.rgb(
                (int) (Color.red(off) + (Color.red(on) - Color.red(off)) * progress),
                (int) (Color.green(off) + (Color.green(on) - Color.green(off)) * progress),
                (int) (Color.blue(off) + (Color.blue(on) - Color.blue(off)) * progress));
        paint.setColor(color);
        paint.setStyle(Paint.Style.FILL);
        canvas.drawRoundRect(track, radius, radius, paint);

        float inset = dp(2);
        float thumbRadius = radius - inset;
        float left = thumbRadius + inset;
        float right = width - thumbRadius - inset;
        float cx = left + (right - left) * progress;
        float cy = height / 2f;

        paint.setColor(0x33000000);
        paint.setShadowLayer(dp(1.5f), 0, dp(1), 0x33000000);
        canvas.drawCircle(cx, cy, thumbRadius, paint);
        paint.setShadowLayer(0, 0, 0, 0);

        paint.setColor(0xFFFFFFFF);
        canvas.drawCircle(cx, cy, thumbRadius, paint);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (!isEnabled()) {
            return false;
        }
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                setPressed(true);
                return true;
            case MotionEvent.ACTION_UP:
                setPressed(false);
                if (isInside(event)) {
                    performClick();
                }
                return true;
            case MotionEvent.ACTION_CANCEL:
                setPressed(false);
                return true;
            default:
                return super.onTouchEvent(event);
        }
    }

    private boolean isInside(MotionEvent event) {
        return event.getX() >= 0 && event.getX() <= getWidth()
                && event.getY() >= 0 && event.getY() <= getHeight();
    }
}
