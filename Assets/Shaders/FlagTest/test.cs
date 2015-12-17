using UnityEngine;
using System.Collections;

public class test : MonoBehaviour {
	public float minimum = 10.0F;
	public float maximum = 20.0F;
	public float duration = 1F;
	private float startTime;

	Vector3 _pre;

	void Start() {
		startTime = Time.time;
		_pre = this.transform.position;
	}
		
	float t = 0f;
	void Update() {
//		float t = (Time.time - startTime) / duration;

		if(t > 1f) return;

	
		transform.position = new Vector3(Mathf.SmoothStep(minimum, maximum, t), 0, 0);
		t += Time.deltaTime;

		var dis = Vector3.Distance(this.transform.position, _pre);

		this._pre = this.transform.position;

		var delta = Time.deltaTime;
		var speed = dis / delta;

		var point = GameObject.Instantiate(this.gameObject);
		GameObject.Destroy(point.GetComponent<test>());

		var pos = this.transform.position;
		pos.x = t*10f;
		pos.y = speed*10f;
		pos.z = 0f;

		point.transform.position = pos;
	}
}