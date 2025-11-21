SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispLPPK03                                          */
/* Creation Date: 28-Jun-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#218876                                                  */   
/*                                                                      */
/* Called By: Load Plan - Generate Pack From Picked                     */
/*                       (isp_LPGenPackFromPicked_Wrapper)              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 24-Mar-2014  TLTING   1.1  SQL2012 Bug                               */
/************************************************************************/

CREATE PROC [dbo].[ispLPPK03]   
   @cLoadKey    NVARCHAR(10),  
   @bSuccess    INT      OUTPUT,
   @nErr        INT      OUTPUT, 
   @cErrMsg     NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @cDebug      NVARCHAR(1),
           @cPickSlipno NVARCHAR(10),  
           @cOldPickSlipNo NVARCHAR(10),
           @cOrderKey   NVARCHAR(10),  
           @cStorerKey  NVARCHAR(15),  
           @cSKU        NVARCHAR(20),  
           @cComponentSKU NVARCHAR(20),  
           @nComponentQty INT,  
           @nQty        INT,  
           @nContinue   INT,
           @nStartTCnt  INT,
           @cCartonGroup    NVARCHAR(10), 
           @cSKUCartonGroup NVARCHAR(10), 
           @cPrevSKUCartonGroup NVARCHAR(10), 
           @nStdCube      DECIMAL(18,4), 
           @nOrderCube    DECIMAL(18,4), 
           @nCartonCube   DECIMAL(18,4),
           @nSkuCube      DECIMAL(18,4),
           @cCartonType NVARCHAR(10),
					 @cNewCartonType NVARCHAR(10),
           @cLabelNo NVARCHAR(20),
           @nPackQty INT,
           @nStdGrossWgt    DECIMAL(18,4), 
           @nOrderGrossWgt  DECIMAL(18,4), 
           @nCartonGrossWgt DECIMAL(18,4),
           @nSkuGrossWgt    DECIMAL(18,4),
           @nOrderQty       INT,
           @nCartonQty      INT,
           @nSkuQty         INT,
           @cLogicalLocation NVARCHAR(18),
           @cLoc             NVARCHAR(10),
           @cPickZone        NVARCHAR(10),
           @cOneCartonFit   NVARCHAR(1),
           @b_success       INT,
           @nCasecnt        INT,
           @nFullCaseCube       DECIMAL(18,4),
           @nFullCaseGrossWgt   DECIMAL(18,4),
           @nFullCaseQty        INT,
           @cFullCaseCheck      NVARCHAR(1),
           @cFullCaseInsert     NVARCHAR(1),
           @cFullCaseDirectPack NVARCHAR(1),
           @cPrevLabelNo NVARCHAR(20),
           @cPrevCartonType NVARCHAR(10),
           @nCartonMaxCube DECIMAL(18,4),
           @nCartonMaxQty  INT,
           @nCartonMaxWeight DECIMAL(18,4),
           @nNumberOfCarton INT,
           @cCartonOptimization NVARCHAR(1),
           @nRowId INT,
           @nCartonNo INT
           
   CREATE TABLE #TMP_PICKSKU
      (StorerKey NVARCHAR(15) NULL, 
      SKU NVARCHAR(20) NULL, 
      cartongroup NVARCHAR(10) NULL, 
      skucartongroup NVARCHAR(10) NULL, 
      Qty int NULL, 
      Stdcube DECIMAL(18,4) NULL,
      StdGrossWgt DECIMAL(18,4) NULL,
      Loc NVARCHAR(10) NULL,
      LogicalLocation NVARCHAR(18) NULL,
      PickZone NVARCHAR(10) NULL,
      Casecnt int NULL)

   CREATE TABLE #TMP_CARTONOPTIMIZATION
      (RowID INT Identity(1,1),
       SkucartonGroup NVARCHAR(10) NULL, 
       CartonType NVARCHAR(10) NULL,
       BalQty INT NULL, 
       BalCube DECIMAL(18,4) NULL,
       BalWeight DECIMAL(18,4) NULL,
       LabelNo NVARCHAR(20) NULL)

	SELECT @nContinue=1, @nStartTCnt=@@TRANCOUNT, @nErr = 0, @cErrMsg = '', @b_success = 1, @cDebug = '0'
  SELECT @cFullCaseCheck = 'Y' -- Y=Ensure full case can fit in the carton. N=full case will break bulk into other carton
  SELECT @cFullCaseDirectPack = 'N' -- Y=Full case direct pack to new carton. N=full case will pack to another carton
  SELECT @cCartonOptimization = 'Y' -- Y=search previous carton to fit in. N=not search for previous carton to fit in.
  
   IF EXISTS(SELECT 1 FROM LOADPLAN WITH (NOLOCK) 
             WHERE LOADPLAN.Status > '3' AND LOADPLAN.Loadkey = @cLoadKey)
   BEGIN
	    SELECT @nContinue=3
	    SELECT @nErr = 39000
	    SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': Picking Started. Not Allow Run Cartonization '
      GOTO QUIT_SP 
   END 
    
   --BEGIN TRAN
   
   DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT OrderKey   
   FROM   LoadplanDetail (NOLOCK)  
   WHERE  loadkey = @cLoadKey   
  
   OPEN CUR_ORDER  
  
   FETCH NEXT FROM CUR_ORDER INTO @cOrderKey   
  
   -- process cartonization by order
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @cPickSlipno = ''      
      SELECT @cPickSlipno = PickheaderKey  
      FROM PickHeader (NOLOCK)  
      WHERE OrderKey = @cOrderKey      
      
      SET @cOldPickslipNo = @cPickSlipno
        
      -- Create Pickheader      
      IF ISNULL(@cPickSlipno ,'') = ''  
      BEGIN  
         EXECUTE dbo.nspg_GetKey   
         'PICKSLIP',   9,   @cPickslipno OUTPUT,   @bSuccess OUTPUT,   @nErr OUTPUT,   @cErrmsg OUTPUT      
           
         SELECT @cPickslipno = 'P'+@cPickslipno      
                    
         INSERT INTO PICKHEADER  
                     (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)  
              VALUES (@cPickslipno , @cLoadKey, @cOrderKey, '0', 'D', '')              
      END 
      
      -- Create PickingInfo with scanned in
      IF (SELECT COUNT(1) FROM PICKINGINFO(NOLOCK) WHERE Pickslipno = @cPickslipno) = 0
      BEGIN
         INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
              VALUES (@cPickslipno ,GETDATE(),sUser_sName(), NULL)
      END
  
      /*
      UPDATE PICKDETAIL WITH (ROWLOCK)  
      SET    PickSlipNo = @cPickSlipNo  
            ,TrafficCop = NULL  
      WHERE  OrderKey = @cOrderKey       
      */
       
      -- Create packheader if not exists      
      IF (SELECT COUNT(1) FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) = 0      
      BEGIN      
         INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)      
                SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo       
                FROM  PICKHEADER PH (NOLOCK)      
                JOIN  Orders O (NOLOCK) ON (PH.Orderkey = O.Orderkey)      
                WHERE PH.PickHeaderKey = @cPickSlipNo  
      END       
      ELSE
      BEGIN
          IF (SELECT COUNT(1) FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) > 0 
             GOTO SKIP_ORDER
      END
      
      IF ISNULL(@cOldPickSlipno ,'') <> ''  --Re-scan in to update all status if the order repack 
      BEGIN
      	 DELETE PickingInfo WHERE PickSlipNo = @cOldPickSlipno
         INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
              VALUES (@cOldPickSlipno ,GETDATE(),sUser_sName(), NULL)
      END
       
      DELETE FROM #TMP_CARTONOPTIMIZATION 
      DELETE FROM #TMP_PICKSKU
 
      -- retrieve pickdetail categorized by prepack and non-prepack item
      INSERT INTO #TMP_PICKSKU (Storerkey, Sku, CartonGroup, Qty, StdCube, StdGrossWgt, SkuCartonGroup, Loc, LogicalLocation, PickZone, Casecnt)
      SELECT PD.StorerKey, PD.SKU, PD.cartongroup, SUM(PD.Qty), CONVERT(DECIMAL(18,4),S.Stdcube) AS Stdcube, CONVERT(DECIMAL(18,4),S.StdGrossWgt) AS StdGrossWgt,
             S.CartonGroup, L.Loc, L.LogicalLocation, L.PickZone, P.Casecnt
      FROM PICKDETAIL PD (NOLOCK)  
      JOIN SKU S (NOLOCK) ON (PD.Storerkey = S.Storerkey AND PD.Sku = S.Sku)
      JOIN LOC L (NOLOCK) ON (PD.Loc = L.Loc)
      JOIN PACK P (NOLOCK) ON (S.Packkey = P.Packkey)
      WHERE PD.OrderKey = @cOrderKey 
      AND PD.Qty > 0   
      AND PD.cartongroup <> 'PREPACK'
      GROUP BY PD.StorerKey, PD.SKU, PD.Cartongroup, S.Stdcube, S.StdGrossWgt, S.CartonGroup, L.Loc, L.LogicalLocation, L.PickZone, P.Casecnt
         UNION ALL
      SELECT PD.StorerKey, PD.altsku, PD.cartongroup, CASE WHEN SUM(B.Qty) > 0 THEN SUM(PD.Qty) / SUM(B.Qty) ELSE SUM(PD.Qty) END AS Qty, 
             CONVERT(DECIMAL(18,4),S.Stdcube) AS Stdcube, CONVERT(DECIMAL(18,4),S.StdGrossWgt) AS StdGrossWgt, S.CartonGroup,
             L.Loc, L.LogicalLocation, L.PickZone, P.Casecnt
      FROM PICKDETAIL PD (NOLOCK)
      JOIN BILLOFMATERIAL B (NOLOCK) ON (PD.Storerkey = B.Storerkey AND PD.Altsku = B.Sku)
      JOIN SKU S (NOLOCK) ON (PD.Storerkey = S.Storerkey AND PD.Altsku = S.Sku)    
      JOIN LOC L (NOLOCK) ON (PD.Loc = L.Loc)
      JOIN PACK P (NOLOCK) ON (S.Packkey = P.Packkey)
      WHERE PD.OrderKey = @cOrderKey 
      AND PD.Qty > 0   
      AND PD.cartongroup = 'PREPACK' 
      GROUP BY PD.StorerKey, PD.altsku, PD.cartongroup, S.Stdcube, S.StdGrossWgt, S.CartonGroup, L.Loc, L.LogicalLocation, L.PickZone, P.Casecnt
          
      SELECT @nOrderCube =  SUM(Qty * CONVERT(DECIMAL(18,4),StdCube)),
             @nOrderGrossWgt = SUM(Qty * CONVERT(DECIMAL(18,4),StdGrossWgt)),   
             @nOrderQty = SUM(QTY)        
      FROM #TMP_PICKSKU  
      
      IF @cDebug = '1'
      BEGIN
      	 SELECT '-----RETRIEVE ORDER-----'
         SELECT '@cOrderkey=', @cOrderkey, '@cPickslipno=', @cPickslipno
         SELECT '@cOrderCube=', @nOrderCube, '@nOrderGrossWgt=', @nOrderGrossWgt, '@nOrderQty=', @nOrderQty
      END 

      SELECT @nCartonCube = 0
            ,@nSkuCube = 0
            ,@nCartonGrossWgt = 0
            ,@nSkuGrossWgt = 0
            ,@nCartonQty = 0
            ,@nSkuQty = 0
            ,@cPrevSKUCartonGroup = ''
            ,@cOneCartonFit = 'N'  
            
      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT StorerKey, SKU, CartonGroup, Qty, StdCube, StdGrossWgt, SkuCartonGroup, Loc, LogicalLocation, PickZone, Casecnt
         FROM #TMP_PICKSKU (NOLOCK)  
         ORDER BY SkuCartonGroup, PickZone, CASE WHEN Casecnt > 0 THEN
                                                 CASE WHEN (Qty % Casecnt) = 0 THEN 0
                                                      WHEN (Qty % Casecnt) > 0 AND Qty > Casecnt THEN 1
                                                 ELSE 2 END
                                            ELSE 9 END,
                  (StdCube * Qty) DESC, (StdGrossWgt * Qty) Desc, Qty Desc, LogicalLocation, Loc, SKU
        
      OPEN CUR_PICKDETAIL  
        
      FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @cCartonGroup, @nQty, @nStdCube, @nStdGrossWgt, 
                                          @cSkuCartonGroup, @cLoc, @cLogicalLocation, @cPickZone, @nCasecnt
      
      --assign carton to the sku sort by carton group, pick zone and location
      WHILE @@FETCH_STATUS<>-1  
      BEGIN  
         IF @nCasecnt = 0
            SELECT @nFullCaseCube = 0, @nFullCaseGrossWgt = 0, @nFullCaseQty = 0
         ELSE
         BEGIN
            SET @nFullCaseCube = @nStdCube * @nCasecnt
    		    SET @nFullCaseGrossWgt = @nStdGrossWgt * @nCaseCnt 
            SET @nFullCaseQty = @nCasecnt
         END

         SET @nSkuCube = @nStdCube * @nQty
         SET @nSkuGrossWgt = @nStdGrossWgt * @nQty 
         SET @nSkuQty = @nQty         
         
         IF @cDebug = '1'
         BEGIN
         	  SELECT  '-----RETRIEVE SKU------'
            SELECT  '@cSKU=', @cSku, '@cCartonGroup=', @cCartonGroup, '@nQty=', @nQty,  '@nStdCube=', @nStdCube,  '@nStdGrossWgt=', @nStdGrossWgt
            SELECT  '@cSkuCartonGroup=', @cSkuCartonGroup, '@cLoc=', @cLoc, '@cLogicalLocation=', @cLogicalLocation,  '@cPickZone=', @cPickZone, '@nCasecnt=',@nCasecnt
            SELECT  '@nFullCaseCube=', @nFullCaseCube, '@nFullCaseGrossWgt=',@nFullCaseGrossWgt, '@nFullCaseQty=', @nFullCaseQty
            SELECT  '@cFullCaseDirectPack=', @cFullCaseDirectPack, '@cFullCaseCheck=', @cFullCaseCheck, '@cCartonOptimization=', @cCartonOptimization
         END
         
         -- Get the maximum capacity of the carton group
         SELECT @nCartonMaxCube = MAX(CONVERT(DECIMAL(18,4),CZ.[Cube])),
                @nCartonMaxWeight = MAX(CONVERT(DECIMAL(18,4),CZ.MaxWeight)),
                @nCartonMaxQty = MAX(CZ.MaxCount)
         FROM CARTONIZATION CZ (NOLOCK)
         WHERE CZ.CartonizationGroup = @cSKUCartonGroup 
         
         -- if full case cannot fit in the largest carton type, pack directly
         IF @nCasecnt > 0 AND @cFullCaseCheck = 'Y' AND 
            (ISNULL(@nCartonMaxCube,0) < (@nStdCube * @nCasecnt) OR ISNULL(@nCartonMaxWeight,0) < (@nStdGrossWgt * @nCasecnt) OR
             ISNULL(@nCartonMaxQty,0) < (@nCasecnt))
         BEGIN
         	  GOTO FULLCASEDIRECTPACK
         END
                  
         IF @nCasecnt > 0 AND @cFullCaseDirectPack = 'Y'  --Direct pack full case without cartonization
         BEGIN         
         	  FULLCASEDIRECTPACK:  	  
            SELECT @nPackQty = 0
            SELECT @cPrevCartonType = @cCartonType
            SELECT @cPrevLabelNo = @cLabelNo
         	  SELECT @nNumberOfCarton = FLOOR(@nQty / @nCasecnt)
         	  
         	  WHILE @nNumberOfCarton > 0
         	  BEGIN         	           	              
               -- New Carton Label for full case
               EXECUTE isp_GenUCCLabelNo
                       @cStorerKey,
                       @cLabelNo  OUTPUT,
                       @b_success  OUTPUT,
                       @nErr      OUTPUT,
                       @cErrMsg    OUTPUT
               
               IF @b_success = 0
               BEGIN
                  SELECT @nContinue = 3
                  GOTO QUIT_SP
               END                 
               
               SELECT @nOrderCube = @nOrderCube - @nFullCaseCube
               SELECT @nSkuCube = @nSkuCube - @nFullCaseCube
                
               SELECT @nOrderGrossWgt = @nOrderGrossWgt - @nFullCaseGrossWgt
               SELECT @nSkuGrossWgt = @nSkuGrossWgt - @nFullCaseGrossWgt
               	 
               SELECT @nOrderQty = @nOrderQty - @nFullCaseQty
               SELECT @nSkuQty = @nSkuQty - @nFullCaseQty
                	 
               SELECT @nQty = @nQty - @nFullCaseQty
               SELECT @nPackQty = @nFullCaseQty
               
               SELECT @cFullCaseInsert = 'Y'
               SELECT @cCartonType = ''
               GOTO INSERT_PACKDETAIL
               FULLCASEPACKING:          
               
               SELECT @nNumberOfCarton = @nNumberOfCarton - 1
            END
            --Continue loose packing on previous carton
            SELECT @cCartonType = @cPrevCartonType
            SELECT @cLabelNo = @cPrevLabelNo 
         END              
   
         --WHILE (@nSkuCube > 0 OR @nSkuGrossWgt > 0 OR @nSkuQty > 0)  -- sku got Balance
         WHILE @nSkuQty > 0  -- sku got Balance
         BEGIN         	  
            IF (ISNULL(@nCartonCube,0) <= 0 AND @nStdCube > 0) OR (ISNULL(@nCartonGrossWgt,0) <= 0 AND @nStdGrossWgt > 0) OR (ISNULL(@nCartonQty,0) <= 0)
               OR (@cPrevSKUCartonGroup = '') OR (@cPrevSKUCartonGroup <> @cSKUCartonGroup)  -- Carton full or new carton group
            BEGIN   
            	 SELECT @cLabelNo = '', @nRowId = 0, @nCartonCube = 0
            	 
            	 -- Searh previous carton got empty space can fit in at least a unit/full case cube/weight with biggest empty space first
            	 IF @cCartonOptimization = 'Y'
            	 BEGIN
            	 	  IF @cFullCaseCheck = 'Y' AND @nSkuQty >= @nCaseCnt AND @nCaseCnt > 0
            	 	  BEGIN
            	 	  	 --at least can fit in a full case cube/weight
                     SELECT TOP 1 @nCartonCube = CONVERT(DECIMAL(18,4),CZ.BalCube), @cCartonType = CZ.Cartontype,
                                  @nCartonGrossWgt = CONVERT(DECIMAL(18,4),CZ.BalWeight), @nCartonQty = CZ.BalQty,
                                  @nRowId = CZ.RowId, @cLabelNo = CZ.LabelNo
                     FROM #TMP_CARTONOPTIMIZATION CZ (NOLOCK)
                     WHERE CZ.SkuCartonGroup = @cSKUCartonGroup 
                     AND CZ.BalCube >= @nFullCaseCube 
                     AND CZ.BalWeight >= @nFullCaseGrossWgt
                     AND CZ.BalQty >= @nFullCaseQty
                     ORDER BY CASE WHEN @nStdCube > 0 THEN CZ.BalCube ELSE 0 END DESC, 
              		   		     CASE WHEN @nStdGrossWgt > 0 THEN CZ.BalWeight ELSE 0 END DESC, 
                              CZ.BalQty DESC
                  END
                  ELSE
            	 	  BEGIN
            	 	  	 --at least can fit in 1 unit cube/weight
                     SELECT TOP 1 @nCartonCube = CONVERT(DECIMAL(18,4),CZ.BalCube), @cCartonType = CZ.Cartontype,
                                  @nCartonGrossWgt = CONVERT(DECIMAL(18,4),CZ.BalWeight), @nCartonQty = CZ.BalQty,
                                  @nRowId = CZ.RowId, @cLabelNo = CZ.LabelNo
                     FROM #TMP_CARTONOPTIMIZATION CZ (NOLOCK)
                     WHERE CZ.SkuCartonGroup = @cSKUCartonGroup 
                     AND CZ.BalCube >= @nSkuCube 
                     AND CZ.BalWeight >= @nStdGrossWgt
                     AND CZ.BalQty > 0
                     ORDER BY CASE WHEN @nStdCube > 0 THEN CZ.BalCube ELSE 0 END DESC, 
              		   		     CASE WHEN @nStdGrossWgt > 0 THEN CZ.BalWeight ELSE 0 END DESC, 
                              CZ.BalQty DESC
                  END                                    
                           
                  IF ISNULL(@nRowID,0) > 0 
                     DELETE #TMP_CARTONOPTIMIZATION WHERE RowID = @nRowID
            	 END
            	 
            	 --Search for best fit empty carton for the remaining order's sku                 
               IF ISNULL(@nCartonCube,0) <= 0 
               BEGIN
                  SELECT TOP 1 @nCartonCube = CONVERT(DECIMAL(18,4),CZ.[Cube]), @cCartonType = CZ.Cartontype,
                               @nCartonGrossWgt = CONVERT(DECIMAL(18,4),CZ.MaxWeight), @nCartonQty = CZ.MaxCount
                  FROM CARTONIZATION CZ (NOLOCK)
                  WHERE CZ.CartonizationGroup = @cSKUCartonGroup 
                  AND CZ.[Cube] >= @nOrderCube 
                  AND CZ.MaxWeight >= @nOrderGrossWgt
                  AND CZ.MaxCount >= @nOrderQty
                  ORDER BY CASE WHEN @nOrderCube > 0 THEN CZ.[Cube] ELSE 0 END,
              	   			  CASE WHEN @nOrderGrossWgt > 0 THEN CZ.MaxWeight ELSE 0 END, 
                           CZ.MaxCount
                  
                  IF @@ROWCOUNT > 0   -- the remaining order's sku can fit in the carton
                     SET @cOneCartonFit = 'Y'      
        END                    
               
               IF ISNULL(@nCartonCube,0) <= 0 
               BEGIN
               	  --get an empty carton based on use sequence (usually large carton)
                  SELECT TOP 1 @nCartonCube = CONVERT(DECIMAL(18,4),CZ.[Cube]), @cCartonType = CZ.Cartontype,
                               @nCartonGrossWgt = CONVERT(DECIMAL(18,4),CZ.MaxWeight), @nCartonQty = CZ.MaxCount
                  FROM CARTONIZATION CZ (NOLOCK)
                  WHERE CZ.CartonizationGroup = @cSKUCartonGroup 
                  ORDER BY CZ.UseSequence
               END               
                                             
               IF ISNULL(@nCartonCube,0) <= 0
               BEGIN
             	   SELECT @nContinue=3
                  SELECT @nErr = 38000
                  SELECT @cErrMsg = 'Cartonization Cube Not Yet Setup For ' + RTRIM(@cStorerkey)
                  GOTO QUIT_SP      
               END

               IF @nCasecnt = 0 OR @cFullCaseCheck = 'N' -- casecnt not setup. the carton must be able to fit in minimum one unit
               BEGIN
                  IF ISNULL(@nCartonCube,0) < @nStdCube
                  BEGIN
             	       SELECT @nContinue=3
                     SELECT @nErr = 38010
                     SELECT @cErrMsg = 'SKU '+ RTRIM(@cSKU)+' StdCude Cannot Fit In Carton Type '+ RTRIM(@cCartonType)
                     GOTO QUIT_SP      
                  END
                  
                  IF ISNULL(@nCartonGrossWgt,0) < @nStdGrossWgt
                  BEGIN
             	       SELECT @nContinue=3
                     SELECT @nErr = 38011
                     SELECT @cErrMsg = 'SKU '+ RTRIM(@cSKU)+' StdGrossWgt * Casecnt Cannot Fit In Carton Type '+ RTRIM(@cCartonType)
                     GOTO QUIT_SP      
                  END
                  
                  IF ISNULL(@nCartonQty,0) < 1 
                  BEGIN
             	       SELECT @nContinue=3
                     SELECT @nErr = 38012
                     SELECT @cErrMsg = 'SKU '+ RTRIM(@cSKU)+' Qty Cannot Fit In Carton Type '+ RTRIM(@cCartonType)
                     GOTO QUIT_SP      
                  END
               END
               /*ELSE -- casecnt setup. the carton must be able to fit in minimum one case
               BEGIN
                  IF ISNULL(@nCartonMaxCube,0) < (@nStdCube * @nCasecnt)
                  BEGIN
             	       SELECT @nContinue=3
                     SELECT @nErr = 38010
                     SELECT @cErrMsg = 'SKU '+ RTRIM(@cSKU)+' StdCude * Casecnt Cannot Fit In Carton Type '+ RTRIM(@cCartonType)
                     GOTO QUIT_SP      
                  END
                  
                  IF ISNULL(@nCartonMaxWeight,0) < (@nStdGrossWgt * @nCasecnt)
                  BEGIN
             	       SELECT @nContinue=3
                     SELECT @nErr = 38011
                     SELECT @cErrMsg = 'SKU '+ RTRIM(@cSKU)+' StdGrossWgt * Casecnt Cannot Fit In Carton Type '+ RTRIM(@cCartonType)
                     GOTO QUIT_SP      
                  END
                  
                  IF ISNULL(@nCartonMaxQty,0) < (@nCasecnt) 
                  BEGIN
             	       SELECT @nContinue=3
                     SELECT @nErr = 38012
                     SELECT @cErrMsg = 'SKU '+ RTRIM(@cSKU)+' Casecnt Cannot Fit In Carton Type '+ RTRIM(@cCartonType)
                     GOTO QUIT_SP      
                  END
               END*/

               -- New Carton Label 
               IF ISNULL(@cLabelno,'') = '' 
               BEGIN
                  EXECUTE isp_GenUCCLabelNo
                        @cStorerKey,
                        @cLabelNo  OUTPUT,
                        @b_success  OUTPUT,
                        @nErr      OUTPUT,
                        @cErrMsg    OUTPUT
                  
                  IF @b_success = 0
                  BEGIN
                      SELECT @nContinue = 3
                      GOTO QUIT_SP
                  END               
               END

               IF @cDebug = '1'
               BEGIN
               	  SELECT '-----NEW CARTON-----'
                  SELECT '@cOneCartonFit=', @cOneCartonFit, '@cLabelNo=', @cLabelNo, '@nRowID=', @nRowID
                  SELECT '@cCartonType=', @cCartonType, '@nCartonCube=', @nCartonCube, '@nCartonGrossWgt', @nCartonGrossWgt, '@nCartonQty=', @nCartonQty 
               END 

            END

            SET @nPackQty = 0
            
            IF @cOneCartonFit = 'Y'  -- The carton can fit in the remaining order's sku
            BEGIN
            	 SELECT @nOrderCube = @nOrderCube - @nSkuCube
               SELECT @nCartonCube = @nCartonCube - @nSkuCube
            	 SELECT @nSkuCube = 0
            	 
            	 SELECT @nOrderGrossWgt = @nOrderGrossWgt - @nSkuGrossWgt
            	 SELECT @nCartonGrossWgt = @nCartonGrossWgt - @nSkuGrossWgt
            	 SELECT @nSkuGrossWgt = 0
            	 
            	 SELECT @nOrderQty = @nOrderQty - @nQty
            	 SELECT @nCartonQty = @nCartonQty - @nQty
            	 SELECT @nSkuQty = 0
             	 
             	 SELECT @nPackQty = @nQty 
            	 SELECT @nQty = 0 
            	 
               IF @cDebug = '1'
               BEGIN
               	   SELECT '-----ONE CARTON FIT------'
                   SELECT '@nCartonCube=', @nCartonCube, '@nCartonGrossWgt', @nCartonGrossWgt, '@nCartonQty=', @nCartonQty 
      	           SELECT '@nOrderCube=', @nOrderCube, '@nOrderGrossWgt=', @nOrderGrossWgt, '@nOrderQty=', @nOrderQty
                   SELECT '@nSkuCube=', @nSkuCube, '@nSkuGrossWgt=', @nSkuGrossWgt, '@nSkuQty=', @nOrderQty
                   SELECT '@nQty=', @nQty, '@nPackQty=', @nPackQty
               END             	
            END
            ELSE
            BEGIN
            	 --assing carton to the sku until carton full or sku no more qty
               WHILE ((@nCartonCube > 0 AND @nSkuCube > 0) OR @nStdCube = 0) 
                     AND ((@nCartonGrossWgt > 0 AND @nSkuGrossWgt > 0) OR @nStdGrossWgt = 0)
                     AND (@nCartonQty > 0 AND @nSkuQty > 0)
               BEGIN               	 
               	  IF @nCasecnt = 0 OR @nCasecnt > @nQty OR @cFullCaseCheck = 'N'  --no casecnt setup or less than one case
               	  BEGIN
                     IF @nCartonCube < @nStdCube OR @nCartonGrossWgt < @nStdGrossWgt
                     BEGIN
                     	  --an unit cannot fit in the carton
										    IF @cCartonOptimization = 'Y' -- Keep the non-full carton for carton optimization
                        BEGIN
               	            IF @nCartonCube > 0 AND @nCartonGrossWgt > 0 AND @nCartonQty > 0
               	        	     INSERT INTO #TMP_CARTONOPTIMIZATION (SkuCartonGroup, CartonType, BalQty, BalCube, BalWeight, LabelNo)
                            	  	    VALUES (@cSkuCartonGroup, @cCartonType, @nCartonQty, @nCartonCube, @nCartonGrossWgt, @cLabelNo)                                          
               	        END
                        SET @nCartonCube = 0
                        SET @nCartonGrossWgt = 0
                        SET @nCartonQty = 0
                        CONTINUE
                     END
                     --deduct an unit
                     SET @nSkuCube = @nSkuCube - @nStdCube    
                     SET @nCartonCube = @nCartonCube - @nStdCube  
                     SET @nOrderCube = @nOrderCube - @nStdCube          
                     
                     SET @nSkuGrossWgt = @nSkuGrossWgt - @nStdGrossWgt
                     SET @nCartonGrossWgt = @nCartonGrossWgt - @nStdGrossWgt
                     SET @nOrderGrossWgt = @nOrderGrossWgt - @nStdGrossWgt          
                     
                     SET @nSkuQty = @nSkuQty - 1
                     SET @nCartonQty = @nCartonQty - 1
                     SET @nOrderQty = @nOrderQty - 1
                     
                     SET @nQty = @nQty - 1
                     SET @nPackQty = @nPackQty + 1        
                  END
                  ELSE
                  BEGIN  --casecnt setup and more than one case                              
                     IF @nCartonCube < @nFullCaseCube OR @nCartonGrossWgt < @nFullCaseGrossWgt OR @nCartonQty < @nFullCaseQty
                     BEGIN
                     	  --full case cannot fit in the carton
										    IF @cCartonOptimization = 'Y' -- Keep the non-full carton for carton optimization
                        BEGIN
               	            IF @nCartonCube > 0 AND @nCartonGrossWgt > 0 AND @nCartonQty > 0
               	        	     INSERT INTO #TMP_CARTONOPTIMIZATION (SkuCartonGroup, CartonType, BalQty, BalCube, BalWeight, LabelNo)
                            	  	    VALUES (@cSkuCartonGroup, @cCartonType, @nCartonQty, @nCartonCube, @nCartonGrossWgt, @cLabelNo)                                          
               	        END
                        SET @nCartonCube = 0
                        SET @nCartonGrossWgt = 0
                        SET @nCartonQty = 0
                        CONTINUE
                     END  
                     --deduct a full case
                     SET @nSkuCube = @nSkuCube - @nFullCaseCube
                     SET @nCartonCube = @nCartonCube - @nFullCaseCube
                     SET @nOrderCube = @nOrderCube - @nFullCaseCube          
                     
                     SET @nSkuGrossWgt = @nSkuGrossWgt - @nFullCaseGrossWgt
                     SET @nCartonGrossWgt = @nCartonGrossWgt - @nFullCaseGrossWgt
                     SET @nOrderGrossWgt = @nOrderGrossWgt - @nFullCaseGrossWgt          
                     
                     SET @nSkuQty = @nSkuQty - @nFullCaseQty
                     SET @nCartonQty = @nCartonQty - @nFullCaseQty
                     SET @nOrderQty = @nOrderQty - @nFullCaseQty
                     
                     SET @nQty = @nQty - @nFullCaseQty
                     SET @nPackQty = @nPackQty + @nFullCaseQty        
                  END     
               END --WHILE
               
               IF @cDebug = '1' AND @cCartonOptimization = 'Y' 
               BEGIN
            	     SELECT * FROM #TMP_CARTONOPTIMIZATION
               END
            END

            IF @cDebug = '1'
            BEGIN
         	     SELECT '-----CARTONIZATION PROCESS------'
               SELECT '@nCartonCube=', @nCartonCube, '@nCartonGrossWgt', @nCartonGrossWgt, '@nCartonQty=', @nCartonQty 
	             SELECT '@nOrderCube=', @nOrderCube, '@nOrderGrossWgt=', @nOrderGrossWgt, '@nOrderQty=', @nOrderQty
               SELECT '@nSkuCube=', @nSkuCube, '@nSkuGrossWgt=', @nSkuGrossWgt, '@nSkuQty=', @nSkuQty
               SELECT '@nQty=', @nQty, '@nPackQty=', @nPackQty
            END             	            
            
            --Insert Packdetail
            SET @cFullCaseInsert = 'N'
            GOTO INSERT_PACKDETAIL
            LOOSEPACKING:                              
         END  --While             
                           
         SET @cPrevSKUCartonGroup = @cSKUCartonGroup
         
         FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @cCartonGroup, @nQty, @nStdCube, @nStdGrossWgt, 
                                             @cSkuCartonGroup, @cLoc, @cLogicalLocation, @cPickZone, @nCasecnt  
      END  
      CLOSE CUR_PICKDETAIL  
      DEALLOCATE CUR_PICKDETAIL      
      
      -- For full case fit rule may have a lot non-full carton, re-optimize the carton type. 
      IF @cFullCaseCheck = 'Y' 
      BEGIN
         SELECT PD.CartonNo, CZ.CartonType, CZ.CartonizationGroup,
                SUM(PD.Qty * CONVERT(DECIMAL(18,4),SKU.StdCube)) AS 'Cube', 
                SUM(PD.Qty * CONVERT(DECIMAL(18,4),SKU.StdGrossWgt)) AS Weight, SUM(PD.Qty) AS Qty
         INTO #CARTONSUMM
         FROM PACKDETAIL PD (NOLOCK)
         JOIN SKU (NOLOCK) ON (PD.Storerkey = PD.Storerkey AND PD.Sku = SKU.Sku)
         JOIN CARTONIZATION CZ (NOLOCK) ON (SKU.CartonGroup = CZ.CartonizationGroup AND PD.RefNo2 = CZ.CartonType)
         WHERE PD.Pickslipno = @cPickSlipNo
         GROUP BY PD.CartonNo, CZ.CartonType, CZ.CartonizationGroup      
         
         SELECT @nCartonNo = 0
         WHILE 1=1      
         BEGIN
         	  --check is there any smaller carton type can fit also
            SELECT TOP 1 @nCartonNo = CTNSUM.CartonNo, @cNewCartonType = CZ.CartonType, @cCartonType = CTNSUM.CartonType 
            FROM #CARTONSUMM CTNSUM
            JOIN CARTONIZATION CZ (NOLOCK) ON (CTNSUM.CartonizationGroup = CZ.CartonizationGroup)
            WHERE CZ.[Cube] >= CTNSUM.[Cube] 
            AND CZ.MaxWeight >= CTNSUM.Weight
            AND CZ.MaxCount >= CTNSUM.Qty
            AND CTNSUM.CartonNo > @nCartonNo
            ORDER BY CTNSUM.CartonNo, CASE WHEN CTNSUM.[Cube] > 0 THEN CZ.[Cube] ELSE 0 END,
              			                  CASE WHEN CTNSUM.Weight > 0 THEN CZ.MaxWeight ELSE 0 END, 
                     CZ.MaxCount
                     
            IF @@ROWCOUNT > 0 AND @cNewCartonType <> @cCartonType
            BEGIN
               UPDATE PACKDETAIL WITH (ROWLOCK)
               SET PACKDETAIL.RefNo2 = @cNewCartonType,
                   PACKDETAIL.ArchiveCop = NULL
               WHERE PACKDETAIL.Pickslipno = @cPickSlipNo
               AND PACKDETAIL.Cartonno = @nCartonno

               IF @cDebug = '1'
               BEGIN
         	        SELECT '-----RE-OPTIMIZE PROCESS------'
                  SELECT '@nCartonNo=', @nCartonNo, '@cCartonType', @cCartonType
               END             	            
            END
            ELSE
              BREAK
         END
         DROP TABLE #CARTONSUMM
      END

      DELETE FROM PACKINFO WHERE PickSlipNo = @cPickSlipno
      
      --Create PACKINFO
      INSERT INTO PACKINFO (Pickslipno, CartonNo, [Cube], CartonType, Weight, Qty)
      SELECT PD.Pickslipno, PD.CartonNo, ISNULL(CZ.[Cube],0), ISNULL(CZ.CartonType,''), SUM(PD.Qty * CONVERT(DECIMAL(18,4),SKU.StdGrossWgt)), SUM(PD.Qty)
      FROM PACKDETAIL PD (NOLOCK)
      JOIN SKU (NOLOCK) ON (PD.Storerkey = PD.Storerkey AND PD.Sku = SKU.Sku)
      LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (SKU.CartonGroup = CZ.CartonizationGroup AND PD.RefNo2 = CZ.CartonType)
      WHERE PD.Pickslipno = @cPickSlipNo
      GROUP BY PD.Pickslipno, PD.CartonNo, CZ.[Cube], CZ.CartonType                  
        
      SKIP_ORDER:
        
      FETCH NEXT FROM CUR_ORDER INTO @cOrderKey      
   END   
   CLOSE CUR_ORDER  
   DEALLOCATE CUR_ORDER 

   QUIT_SP:
   
	IF @nContinue=3  -- Error Occured - Process AND Return
	BEGIN
	   SELECT @bSuccess = 0
		IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @nStartTCnt
		BEGIN
			ROLLBACK TRAN
		END
		ELSE
		BEGIN
			WHILE @@TRANCOUNT > @nStartTCnt
			BEGIN
				COMMIT TRAN
			END
		END
		EXECUTE dbo.nsp_LogError @nErr, @cErrmsg, 'ispLPPK03'		
		--RAISERROR (@cErrmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	END
	ELSE
	BEGIN
	   SELECT @bSuccess = 1
		WHILE @@TRANCOUNT > @nStartTCnt
		BEGIN
			COMMIT TRAN
		END
		RETURN
	END  
	
	-----------------Insert Packdetail Start---------------------
	INSERT_PACKDETAIL:
	IF @cCartonGroup = 'PREPACK'
  BEGIN               
     -- CartonNo and LabelLineNo will be inserted by trigger 
     DECLARE CUR_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
     SELECT ComponentSku, Qty 
        FROM BILLOFMATERIAL (NOLOCK)
        WHERE Storerkey = @cStorerkey
        AND Sku = @cSku
        ORDER BY ComponentSku

     OPEN CUR_BOM 
  
     FETCH NEXT FROM CUR_BOM INTO @cComponentSku, @nComponentQty
     --retrieve prepack component sku
     WHILE @@FETCH_STATUS<>-1  
     BEGIN  
	  IF EXISTS(SELECT 1 FROM PACKDETAIL PD (NOLOCK) WHERE PD.Pickslipno = @cPickslipno AND LabelNo = @cLabelno AND Sku = @cComponentSKU) 
     	  BEGIN
     	     UPDATE PACKDETAIL WITH (ROWLOCK)
     	     SET Qty = Qty + (@nPackQty * @nComponentQty)
     	     WHERE Pickslipno = @cPickSlipNo
     	     AND LabelNo = @cLabelNo
     	     AND Sku = @cComponentSKU
        END
     	  ELSE
     	  BEGIN               	  	 
           INSERT INTO PACKDETAIL     
              (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno2)    
           VALUES     
              (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cComponentSKU,   
               @nPackQty * @nComponentQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cCartonType)
        END    
        IF @@ERROR <> 0
        BEGIN
           SELECT @nContinue = 3
           SELECT @nErr = 38003
           SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Insert/Update PackDetail Table (ispLPPK03)' 
           GOTO QUIT_SP
        END

        FETCH NEXT FROM CUR_BOM INTO @cComponentSku, @nComponentQty
     END
     CLOSE CUR_BOM  
     DEALLOCATE CUR_BOM
  END
  ELSE
  BEGIN   -- non-prepack item            
     IF EXISTS(SELECT 1 FROM PACKDETAIL PD (NOLOCK) WHERE PD.Pickslipno = @cPickslipno AND LabelNo = @cLabelno AND Sku = @cSKU) 
     BEGIN
        UPDATE PACKDETAIL WITH (ROWLOCK)
        SET Qty = Qty + @nPackQty
        WHERE Pickslipno = @cPickSlipNo
        AND LabelNo = @cLabelNo
        AND Sku = @cSKU
     END
     ELSE
     BEGIN
        -- CartonNo and LabelLineNo will be inserted by trigger    
        INSERT INTO PACKDETAIL     
           (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno2)    
        VALUES     
           (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU,   
            @nPackQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cCartonType)
     END
     
     IF @@ERROR <> 0
     BEGIN
        SELECT @nContinue = 3
        SELECT @nErr = 38004
        SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Insert PackDetail Table (ispLPPK03)' 
        GOTO QUIT_SP
     END
  END
  IF @cFullCaseInsert = 'N'
     GOTO LOOSEPACKING
  ELSE
     GOTO FULLCASEPACKING
  ----------------------Insert Packdetail End---------------------------
END

GO