SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[isp_PreCartonize_PackDetail_Summary] (
	@cPickSlipNo NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   	
	DECLARE @cPickSlipType  NVARCHAR(10),
	        @cOrderKey      NVARCHAR(10),
	        @cLoadKey       NVARCHAR(10), 
	        @cConsoOrderKey NVARCHAR(30)
	        
	SELECT @cPickSlipType  = '',
	       @cOrderKey      = '',
	       @cLoadKey       = '',
	       @cConsoOrderKey = ''
	
	SELECT @cPickSlipType  = p.Zone,
	       @cOrderKey      = p.OrderKey,
	       @cLoadKey       = p.ExternOrderKey,
	       @cConsoOrderKey = p.ConsoOrderKey  
	FROM PICKHEADER p WITH (NOLOCK)
	WHERE p.PickHeaderKey = @cPickSlipNo
	
	IF @cPickSlipType <> 'LP' AND ISNULL(RTRIM(@cOrderKey),'') <> ''
	BEGIN
      SELECT OrderDetail.StorerKey,   
	      OrderDetail.Sku,   
	      Sum(OrderDetail.QtyAllocated+OrderDetail.QtyPicked+OrderDetail.ShippedQty) PickedQty,   
	      PackedQty = ISNULL((	SELECT SUM(PACKDETAIL.Qty)   
			      FROM	  PACKDETAIL(NOLOCK)   
			      WHERE	PACKDETAIL.PickSlipNo = PickHeader.PickHeaderkey   
			      AND	PACKDETAIL.Storerkey = OrderDetail.Storerkey     
			      AND	PACKDETAIL.SKU = OrderDetail.SKU), 0),   
	      0 OtherQty, 
         ExpQty = ISNULL((	SELECT SUM(PACKDETAIL.ExpQty)   
			      FROM	  PACKDETAIL(NOLOCK)   
			      WHERE	PACKDETAIL.PickSlipNo = PickHeader.PickHeaderkey   
			      AND	PACKDETAIL.Storerkey = OrderDetail.Storerkey     
			      AND	PACKDETAIL.SKU = OrderDetail.SKU), 0)
       FROM OrderDetail WITH (NOLOCK)
       JOIN PickHeader WITH (NOLOCK) ON (OrderDetail.Orderkey = PickHeader.OrderKey) 
       WHERE ( PICKHEADER.OrderKey IS NOT NULL AND PICKHEADER.OrderKey <> '' )
       AND	 PickHeader.PickHeaderkey = @cPickSlipNo  
       AND   Pickheader.Zone<>'LP'
      GROUP BY PickHeader.PickHeaderkey,  OrderDetail.StorerKey, OrderDetail.Sku   
      HAVING Sum(OrderDetail.QtyAllocated+OrderDetail.QtyPicked+OrderDetail.ShippedQty) > 0
		
	END
	ELSE IF @cPickSlipType = 'LP' AND ISNULL(RTRIM(@cOrderKey),'') <> ''
	BEGIN
      SELECT PickDetail.StorerKey,   
	      PickDetail.Sku,   
	      Sum(Pickdetail.Qty) PickedQty,   
	      PackedQty = ISNULL((	SELECT SUM(PACKDETAIL.Qty)   
			      FROM	  PACKDETAIL(NOLOCK)   
			      WHERE	PACKDETAIL.PickSlipNo = PickHeader.PickHeaderkey   
			      AND	PACKDETAIL.Storerkey = PickDetail.Storerkey     
			      AND	PACKDETAIL.SKU = PickDetail.SKU), 0),   
	      0 OtherQty, 
         ExpQty = ISNULL((	SELECT SUM(PACKDETAIL.ExpQty)   
			      FROM	  PACKDETAIL(NOLOCK)   
			      WHERE	PACKDETAIL.PickSlipNo = PickHeader.PickHeaderkey   
			      AND	PACKDETAIL.Storerkey = PickDetail.Storerkey     
			      AND	PACKDETAIL.SKU = PickDetail.SKU), 0)
       FROM PickDetail WITH (NOLOCK) 
       JOIN PickHeader WITH (NOLOCK) ON PickDetail.Orderkey = PickHeader.OrderKey    
       JOIN RefKeyLookup WITH (NOLOCK) ON RefKeyLookup.PickDetailKey = PickDetail.PickDetailKey 
                                       AND RefKeyLookup.PickSlipNo = PickHeader.PickHeaderKey  
       WHERE   PICKHEADER.OrderKey IS NOT NULL AND PICKHEADER.OrderKey <> ''  
       AND	 PickHeader.PickHeaderkey = @cPickSlipNo   
       AND Pickheader.Zone='LP' 
      GROUP BY PickHeader.PickHeaderkey,  PickDetail.StorerKey, PickDetail.Sku 
      HAVING Sum(PickDetail.Qty) > 0  		
	END 
   ELSE IF @cPickSlipType = 'LP' AND ISNULL(RTRIM(@cConsoOrderKey),'') <> ''
	BEGIN
      SELECT PickDetail.StorerKey,   
	      PickDetail.Sku,   
	      Sum(Pickdetail.Qty) PickedQty,   
	      PackedQty = ISNULL((	SELECT SUM(PACKDETAIL.Qty)   
			      FROM	  PACKDETAIL(NOLOCK)   
			      WHERE	PACKDETAIL.PickSlipNo = PickHeader.PickHeaderkey   
			      AND	PACKDETAIL.Storerkey = PickDetail.Storerkey     
			      AND	PACKDETAIL.SKU = PickDetail.SKU), 0),   
	      0 OtherQty, 
         ExpQty = ISNULL((	SELECT SUM(PACKDETAIL.ExpQty)   
			      FROM	  PACKDETAIL(NOLOCK)   
			      WHERE	PACKDETAIL.PickSlipNo = PickHeader.PickHeaderkey   
			      AND	PACKDETAIL.Storerkey = PickDetail.Storerkey     
			      AND	PACKDETAIL.SKU = PickDetail.SKU), 0)
       FROM PICKHEADER WITH (NOLOCK)
       JOIN RefKeyLookup WITH (NOLOCK) ON RefKeyLookup.PickSlipNo = PickHeader.PickHeaderKey  
       JOIN PickDetail WITH (NOLOCK) ON RefKeyLookup.PickDetailKey = PickDetail.PickDetailKey  
       JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = PickDetail.OrderKey AND 
                                            OD.OrderLineNumber = PickDetail.OrderLineNumber AND
                                            OD.ConsoOrderKey = PICKHEADER.ConsoOrderKey 
       WHERE PICKHEADER.ConsoOrderKey = @cConsoOrderKey 
       AND   OD.ConsoOrderKey = @cConsoOrderKey   
       AND	 PickHeader.PickHeaderkey = @cPickSlipNo   
       AND   Pickheader.Zone='LP' 
      GROUP BY PickHeader.PickHeaderkey,  PickDetail.StorerKey, PickDetail.Sku 
      HAVING Sum(PickDetail.Qty) > 0  		
	END    	         
   ELSE IF ISNULL(RTRIM(@cLoadKey),'') <> '' AND ISNULL(RTRIM(@cOrderKey),'') = ''
   BEGIN
      SELECT OrderDetail.StorerKey,   
	      OrderDetail.Sku,   
	      Sum(OrderDetail.QtyAllocated+OrderDetail.QtyPicked+OrderDetail.ShippedQty) PickedQty,   
	      PackedQty = ISNULL((	SELECT SUM(PACKDETAIL.Qty)   
			      FROM	  PACKDETAIL(NOLOCK)   
			      WHERE	PACKDETAIL.PickSlipNo = PickHeader.PickHeaderkey   
			      AND	PACKDETAIL.Storerkey = OrderDetail.Storerkey     
			      AND	PACKDETAIL.SKU = OrderDetail.SKU), 0),   
	      0 OtherQty,
         ExpQty = ISNULL((	SELECT SUM(PACKDETAIL.ExpQty)   
			      FROM	  PACKDETAIL(NOLOCK)   
			      WHERE	PACKDETAIL.PickSlipNo = PickHeader.PickHeaderkey   
			      AND	PACKDETAIL.Storerkey = OrderDetail.Storerkey     
			      AND	PACKDETAIL.SKU = OrderDetail.SKU), 0)
       FROM OrderDetail WITH (NOLOCK), PickHeader WITH (NOLOCK), LoadplanDetail WITH (NOLOCK) 
       WHERE PickHeader.ExternOrderKey = LOADPLANDETAIL.LoadKey 
       AND   OrderDetail.OrderKey = LOADPLANDETAIL.OrderKey  
       AND   ( PICKHEADER.OrderKey IS NULL OR PICKHEADER.OrderKey = '' ) 
       AND	PickHeader.PickHeaderkey = @cPickSlipNo  
       AND  LoadplanDetail.LoadKey = @cLoadKey   
      GROUP BY PickHeader.PickHeaderkey,  OrderDetail.StorerKey, OrderDetail.Sku     
      HAVING Sum(OrderDetail.QtyAllocated+OrderDetail.QtyPicked+OrderDetail.ShippedQty) > 0
   END  
END

GO