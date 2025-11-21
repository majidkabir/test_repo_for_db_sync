SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure:  ispPRALC01                                        */  
/* Creation Date: 11-Apr-2016                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  SOS#368353                                                 */  
/*                                                                      */  
/* Called By: ispPRALC01                                                */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/* 11-Apr-2016  SHONG   1.0   Initial Version                           */  
/************************************************************************/  
CREATE PROC [dbo].[ispPRALC01] (
     @c_OrderKey        NVARCHAR(10)  
   , @c_LoadKey         NVARCHAR(10)    
   , @b_Success         INT           OUTPUT    
   , @n_Err             INT           OUTPUT    
   , @c_ErrMsg          NVARCHAR(250) OUTPUT    
   , @b_debug           INT = 0 )
 AS 
 BEGIN
 	SET NOCOUNT ON 
 	
 	DECLARE 
 		     @c_OrderLineNumber nvarchar(5)
 	      , @c_SKU             nvarchar(20)
 	      , @c_StorerKey       nvarchar(15)
 	      , @c_LOC             nvarchar(10)
 	      , @n_Qty             INT
 	      , @c_LOT             nvarchar(10)
 	      , @c_ID              nvarchar(18) 
 	      , @n_QtyAvailable    INT
 	      , @c_PickDetailKey   NVARCHAR(10) 
 	      , @c_UOM             NVARCHAR(10)
 	      , @c_PackKey         NVARCHAR(10) 
 	
 	DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
 	SELECT DISTINCT OD.StorerKey, OD.OrderKey, OD.OrderLineNumber, OD.Sku, (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked)),  
 	       OD.Lottable07 
 	FROM ORDERS AS o WITH (NOLOCK) 
 	JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = o.OrderKey  	 
 	LEFT OUTER JOIN LoadPlanDetail LPD WITH (NOLOCK) ON o.OrderKey = LPD.OrderKey 
 	WHERE o.OrderKey = CASE WHEN ISNULL(RTRIM(@c_OrderKey),'') = '' THEN O.OrderKey ELSE @c_OrderKey END 
 	AND  ( LPD.LoadKey = CASE WHEN ISNULL(RTRIM(@c_LoadKey),'') = '' THEN LPD.LoadKey ELSE @c_LoadKey END OR 
 	       ( LPD.LoadKey IS NULL AND ISNULL(RTRIM(@c_LoadKey),'') = '' ) ) 
 	AND (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked)) > 0 
 
 	
 	OPEN CUR_ORDER_LINES
 	
 	FETCH FROM CUR_ORDER_LINES INTO @c_StorerKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @n_Qty, @c_LOC 
 	
 	WHILE @@FETCH_STATUS = 0
 	BEGIN
 		DECLARE CUR_LOTxLOCxID_Qty CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
 		SELECT Lot, Id, Qty - QtyAllocated - QtyPicked
 		FROM LOTxLOCxID WITH (NOLOCK) 
 		WHERE StorerKey = @c_StorerKey 
 		AND   SKU = @c_SKU 
 		AND   LOC = @c_LOC 
 		AND   Qty - QtyAllocated - QtyPicked > 0 
 		
 		OPEN CUR_LOTxLOCxID_Qty
 		
 		FETCH FROM CUR_LOTxLOCxID_Qty INTO @c_Lot, @c_Id, @n_QtyAvailable
 		
 		WHILE @@FETCH_STATUS = 0
 		BEGIN
 			IF @n_QtyAvailable > 0 AND @n_Qty > 0 
 			BEGIN
 				--SELECT @c_LOC '@c_LOC', @c_Lot '@c_Lot', @c_Id '@c_Id', @n_QtyAvailable '@n_QtyAvailable', @n_Qty '@n_Qty', @c_SKU '@c_SKU'
 				
 				SET @b_Success = 0 
 			   EXEC nspg_GetKey
 				   @KeyName = 'PickdetailKey',
 				   @fieldlength = 10,
 				   @keystring = @c_PickDetailKey OUTPUT,
 				   @b_Success = @b_Success OUTPUT,
 				   @n_err = @n_Err OUTPUT,
 				   @c_errmsg = @c_ErrMsg OUTPUT,
 				   @b_resultset = 1,
 				   @n_batch = 1

            IF @b_Success = 1
            BEGIN
            	SELECT @c_UOM = pack.PackUOM3, 
            	       @c_PackKey = pack.PackKey 
            	FROM  SKU WITH (NOLOCK)
            	JOIN  PACK AS Pack WITH (NOLOCK) ON Pack.PACKKey = SKU.PACKKey
            	WHERE SKU.StorerKey = @c_StorerKey
            	AND   SKU.Sku = @c_SKU
            	
            	IF @n_QtyAvailable > @n_Qty 
            	BEGIN
            		SET @n_QtyAvailable = @n_Qty
            		
            	   --SELECT '---', @n_QtyAvailable '@n_QtyAvailable', @n_Qty '@n_Qty', @c_SKU '@c_SKU'	
            	END
            	   
            	INSERT INTO PICKDETAIL
            	(
            		PickDetailKey,          CaseID,            	PickHeaderKey,
            		OrderKey,               OrderLineNumber,     Lot,
            		Storerkey,              Sku,            		AltSku,
            		UOM,           		   UOMQty,            	Qty,
            		QtyMoved,               [Status],            DropID,
            		Loc,            		   ID,            		PackKey,
            		UpdateSource,           CartonGroup,         CartonType,
            		ToLoc,            	   DoReplenish,         ReplenishZone,
            		DoCartonize,            PickMethod,          WaveKey,
            		ShipFlag,               PickSlipNo,          TaskDetailKey,
            		TaskManagerReasonKey,   Notes,            	MoveRefKey    )
            	VALUES
            	(  @c_PickDetailKey,    '',            		'',
            		@c_OrderKey,         @c_OrderLineNumber,  @c_LOT,
            		@c_StorerKey,        @c_SKU,           	'',
            		@c_UOM,            	@n_QtyAvailable,     @n_QtyAvailable,
            		0,            		   '0',            		'',
            		@c_LOC,            	@c_ID,            	@c_PackKey,
            		'',            		'',            		'',
            		'',            		'N',            		'',
            		'N',            		'',            		'',
            		'N',            		'',            		'',
            		'',            		'',            		'' )
            		
            	SET @n_Qty = @n_Qty - @n_QtyAvailable 
            END -- GetKey @b_Success = 1				
 			END 
 			ELSE 
 				BREAK 
 			
 			FETCH FROM CUR_LOTxLOCxID_Qty INTO @c_Lot, @c_Id, @n_QtyAvailable
 		END -- CUR_LOTxLOCxID_Qty Loop
 		CLOSE CUR_LOTxLOCxID_Qty
 		DEALLOCATE CUR_LOTxLOCxID_Qty		
 	
 		FETCH FROM CUR_ORDER_LINES INTO @c_StorerKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @n_Qty, @c_LOC 
 	END -- CUR_ORDER_LINES
 	
 	CLOSE CUR_ORDER_LINES
 	DEALLOCATE CUR_ORDER_LINES
 	
 END    

GO