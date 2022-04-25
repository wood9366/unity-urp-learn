using UnityEngine;

public class SelectableObject : MonoBehaviour
{
    private bool _isSelected = false;

    void OnMouseDown()
    {
        _isSelected = !_isSelected;

        var renderer = GetComponent<Renderer>();

        if (_isSelected)
        {
            renderer.renderingLayerMask |= 1u << 31;
        }
        else
        {
            renderer.renderingLayerMask &= ~(1u << 31);
        }
    }
}
