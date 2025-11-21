SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_Gen_CNA_SUP                                    */
/* Creation Date:                                                       */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   VER  Purposes                                  */
/* 08-Apr-16   Shong     1.0  Initial Version SOS# 368128               */
/* 29-Jun-16   TLTING    1.1  Bug fix - order by invalid column         */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_Gen_CNA_SUP] 
(
	@cLoadkey NVARCHAR(10)
)
AS
BEGIN
	SET NOCOUNT ON
	
   DECLARE
      @n_starttrancnt  INT, 
      @n_continue      INT,
      @b_success       int,
      @n_err           int,
      @c_errmsg        NVARCHAR(255)       

   SELECT @n_starttrancnt = @@TRANCOUNT, @n_continue = 1
         	
	DECLARE  
	      @cSKU          NVARCHAR(20),
	      @cDiv          NVARCHAR(20),
	      @cClass        NVARCHAR(20),
	      @cStop         NVARCHAR(10),
	      @cLoc          NVARCHAR(10),
	      @nMeasurement  INT,
	      @nQty          INT,
	      @nCartonQty    INT,
	      @nMaxCarton    INT,
	      @nLooseCarton  INT,
         @nTotalCarton  INT,
         @nSRow         INT,
         @nCount        INT
		
	CREATE TABLE #Result
	(
		TYPE            NVARCHAR(1),
		Loadkey         NVARCHAR(10),
		PickMethod      NVARCHAR(10),
		Loc             NVARCHAR(10),
		SKU             NVARCHAR(20),
		Div             NVARCHAR(20),
		Class           NVARCHAR(20),
		Measurement     INT,
		CartonNo        INT,
		Qty             INT,
		QUOM            INT,
		TotalCarton     INT
	)
		
	IF EXISTS(SELECT 1 FROM LoadPlanDetail AS lpd WITH (NOLOCK) 
	                   JOIN ORDERS AS O WITH (NOLOCK) ON O.LoadKey = lpd.LoadKey 
	          WHERE lpd.LoadKey = @cLoadkey 
	          AND  o.[STOP] = 'PCS')
	BEGIN
		RETURN
	END
	
	DECLARE CUR_PickRecords CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
	SELECT ORDERS.Stop,
	      PICKDETAIL.Loc,
	      PICKDETAIL.SKU,
	      SKU.BUSR3  AS Div,
	      SKU.class  AS Class,
	      CAST(CAST(SKU.Measurement AS FLOAT) AS INT) AS Measurement,
	      SUM(PICKDETAIL.Qty)  AS Qty,
	      SUM(PICKDETAIL.Qty * CEILING(CAST(SKU.Measurement AS FLOAT))) AS CartonQty
	FROM	PICKDETAIL WITH (NOLOCK)
	INNER JOIN SKU WITH (NOLOCK) ON  PICKDETAIL.Storerkey = SKU.Storerkey
	                           AND PICKDETAIL.SKU = SKU.SKU
	INNER JOIN Orders WITH (NOLOCK) ON  PICKDETAIL.Orderkey = ORDERS.Orderkey
	INNER JOIN LOC WITH (NOLOCK) ON  PICKDETAIL.Loc = LOC.Loc 
	JOIN LoadPlanDetail AS lpd WITH (NOLOCK) ON lpd.OrderKey = Orders.OrderKey
	WHERE lpd.Loadkey = @cLoadkey
     AND ORDERS.[Stop] <> 'PCS'
     AND ORDERS.[Type] = '0' 
     AND ISNUMERIC(SKU.Measurement) = 1 
	GROUP BY
	      LOC.Logicallocation,
	      ORDERS.[Stop],
	      PICKDETAIL.Loc,
	      PICKDETAIL.SKU,
	      SKU.BUSR3,
	      SKU.CLASS,
	      CAST(CAST(SKU.Measurement AS FLOAT) AS INT)
	ORDER BY
	      CAST(CAST(SKU.Measurement AS FLOAT) AS INT) DESC,    -- tlting
	      LOC.Logicallocation,
	      PICKDETAIL.loc,
	      PICKDETAIL.SKU
	    
	OPEN CUR_PickRecords
	FETCH NEXT FROM CUR_PickRecords INTO @cStop, @cLoc, @cSKU, @cDiv, @cClass, @nMeasurement, @nQty, @nCartonQty
	WHILE @@FETCH_STATUS <> -1 
	BEGIN    
	   SELECT @nMaxCarton = ISNULL(MAX(CartonNo), 0)
	   FROM  #Result
	   WHERE loadkey = @cLoadkey

	     AND Measurement <> '0'

      --SELECT @nMaxCarton '@nMaxCarton', @nCartonQty '@nCartonQty', @cSKU '@cSKU', @nMeasurement '@nMeasurement'
       
      SET @nCount = 1
      WHILE @nCount <= @nCartonQty AND @nMeasurement >= 1
      BEGIN
	      INSERT INTO #Result([TYPE], Loadkey, PickMethod, Loc, SKU, Div, Class, Measurement, CartonNo, Qty, QUOM,
	                  TotalCarton )
	      VALUES('0',           @cLoadkey,   @cStop,   @cLoc,
	             @cSKU,         @cDiv,       @cClass,
	             @nMeasurement, @nMaxCarton + @nCount, 0, 0, 0)
	             
	      SET @nCount = @nCount + 1 
      END
      	        
	   IF @nMeasurement >= 1
	   BEGIN
	      UPDATE #Result
	         SET QUOM = CASE 
	                       WHEN (CartonNo = @nMaxCarton + 1) THEN 1
	                       WHEN (CartonNo - @nMaxCarton - 1) % @nMeasurement = 0 THEN 1
	                       ELSE 0
	                    END
	      WHERE Loadkey = @cLoadkey
	      AND   Loc     = @cLoc
	      AND   SKU     = @cSKU     	
	   END
	   ELSE IF @nMeasurement < 1
	   BEGIN
	      --INSERT INTO #Result([TYPE], Loadkey, PickMethod, Loc, SKU, Div, Class, Measurement, CartonNo, Qty, QUOM,
	      --            TotalCarton )
	      --VALUES('0',            @cLoadkey,    @cStop,   @cLoc,
	      --        @cSKU,         @cDiv,        @cClass,	      
	      --        @nMeasurement, @nMaxCarton + 1,  @nQty, 0, 0)
         WHILE @nCount <= @nCartonQty 
         BEGIN
	         INSERT INTO #Result([TYPE], Loadkey, PickMethod, Loc, SKU, Div, Class, Measurement, CartonNo, Qty, QUOM,
	                     TotalCarton )
	         VALUES('0',           @cLoadkey,   @cStop,   @cLoc,
	                @cSKU,         @cDiv,       @cClass,
	                @nMeasurement, @nMaxCarton + 1, 0, 0, 0)
	             
	         SET @nCount = @nCount + 1 
         END
      
	      INSERT INTO #Result([TYPE], Loadkey, PickMethod, Loc, SKU, Div, Class, Measurement, CartonNo, Qty, QUOM,
	                  TotalCarton )
	      VALUES('1',            @cLoadkey,    @cStop,   @cLoc,
	              @cSKU,         @cDiv,        @cClass,
	              @nMeasurement, @nMaxCarton + 1,  @nQty, 0, 0)
	              	     
	      UPDATE #Result
	      SET    QUOM   = Qty
	      WHERE Loadkey = @cLoadkey
	      AND   Loc     = @cLoc
	      AND   SKU     = @cSKU 
	      AND   [Type] = '1'	               		                         
	   END
	   
	   FETCH NEXT FROM CUR_PickRecords INTO @cStop, @cLoc, @cSKU, @cDiv, @cClass, @nMeasurement, @nQty, @nCartonQty
	END    
	CLOSE CUR_PickRecords
	DEALLOCATE CUR_PickRecords
	
	SELECT @nTotalCarton = MAX(cartonNo)
	FROM   #Result
	WHERE  Loadkey = @cLoadkey
	    
	UPDATE #Result
	SET    TotalCarton = @nTotalCarton
	WHERE  Loadkey = @cLoadkey
	
	IF EXISTS(SELECT 1 FROM LoadPlan_SUP_Detail AS lpsd WITH (NOLOCK) WHERE lpsd.Loadkey = @cLoadkey)
	BEGIN
		DELETE FROM LoadPlan_SUP_Detail
		WHERE Loadkey = @cLoadkey
	END 
	INSERT INTO LoadPlan_SUP_Detail
	(
		[TYPE],	Loadkey,		   PickMethod,
		Loc,		SKU,		      Div,
		Class,	Measurement,	CartonNo,
		Qty,		QUOM,		      TotalCarton 
	)
	SELECT 
	   [TYPE],		Loadkey,		   PickMethod,
		Loc,		   SKU,		      Div,
		Class,		Measurement,	CartonNo,
		Qty,		   QUOM,		      TotalCarton  
	FROM #Result AS r
	IF @@ERROR <> 0 
	BEGIN
		SET @n_continue=3
      SELECT @n_err = 63504
      SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': INSERT LoadPlan_SUP_Detail Failed. (isp_Gen_CNA_SUP)'
	END
	
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_Gen_CNA_SUP'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END 

GO