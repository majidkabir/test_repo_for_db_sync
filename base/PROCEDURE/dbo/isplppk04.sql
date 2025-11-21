SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispLPPK04                                          */
/* Creation Date: 05-Jun-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#246185 - EA Generate Pack (Cartonization)               */   
/*                                                                      */
/* Called By: Load Plan (RCM Generate Pack From Pick)                   */
/*            Storerconfig LPGENPACKFROMPICKED                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 14-Jun-2012  NJOW01   1.0  246185 - Change to 8 decimal point        */
/* 19-Jun-2012  NJOW02   1.1  246185 - Include Weight measurement       */
/* 13 Nov 2013  TLTING   1.1  Blocking Tune                             */
/* 24-Mar-2014  TLTING   1.2  SQL2012 Bug                               */
/************************************************************************/

CREATE PROC [dbo].[ispLPPK04]   
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
     
   DECLARE @cPickSlipno NVARCHAR(10),  
           @cOrderKey   NVARCHAR(10),  
           @cStorerKey  NVARCHAR(15),  
           @cSKU        NVARCHAR(20),  
           @nQty        INT,  
           @nContinue   INT,
           @nStartTCnt  INT,
           @cPutawayzone NVARCHAR(10), 
           @cPrevPutawayzone NVARCHAR(10), 
           @nStdCube      DECIMAL(20,8), 
           @nOrderCube    DECIMAL(20,8), 
           @nCartonCube   DECIMAL(20,8),
           @nSkuCube      DECIMAL(20,8),
           @cCartonizationGroup NVARCHAR(10),
           @cCartonType NVARCHAR(10),
           @cLabelNo NVARCHAR(20),
           @nPackQty INT,
           @cStdCubeWgtNotFit NVARCHAR(1),
           @cLoc NVARCHAR(10),
           @cLot NVARCHAR(10),
           @nStdNetWgt    DECIMAL(20,8), 
           @nOrderNetWgt  DECIMAL(20,8), 
           @nCartonNetWgt DECIMAL(20,8),
           @nSkuNetWgt    DECIMAL(20,8),
           @cBatch_PickSlipno NVARCHAR(10),
           @nBatch_PickSlipno INT,           
           @nPS_count   INT           
           
   CREATE TABLE #TMP_PICKSKU
      (StorerKey NVARCHAR(15) NULL, 
      SKU NVARCHAR(20) NULL, 
      Putawayzone NVARCHAR(10) NULL, 
      Qty int NULL, 
      Stdcube DECIMAL(20,8) NULL,
      StdNetWgt DECIMAL(20,8) NULL,
      Loc NVARCHAR(10) NULL,
      Lot NVARCHAR(10) NULL)

	SELECT @nContinue=1, @nStartTCnt=@@TRANCOUNT, @nErr = 0, @cErrMsg = ''
                  
   IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
             JOIN  ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
             WHERE PD.Status='4' AND PD.Qty > 0 
              AND  O.LoadKey = @cLoadKey)
   BEGIN
	   SELECT @nContinue=3
	   SELECT @nErr = 39000
	   SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': Found Short Pick with Qty > 0 '
      GOTO QUIT_SP 
   END 
   
   SET @cSKU = ''
   
   SELECT TOP 1 @cSKU = PD.SKU
   FROM ORDERS O (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON (O.Orderkey = PD.Orderkey)
   JOIN SKU (NOLOCK) ON (PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku)
   WHERE (ISNULL(SKU.StdCube,0) <= 0    
   OR ISNULL(SKU.StdNetWgt,0) <= 0)
   AND O.LoadKey = @cLoadKey
   ORDER BY PD.Sku
   
   IF ISNULL(@cSKU,'') <> ''
   BEGIN
 	    SELECT @nContinue=3
	    SELECT @nErr = 39010
	    SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': SKU ' + RTRIM(@cSKU) + ' Not Yet Setup StdCube Or StdNetWgt'
      GOTO QUIT_SP 
   END 

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
      
   IF @nContinue = 1 OR @nContinue = 2
   BEGIN  

      SELECT @nPS_count = Count(1)   
      FROM   LoadplanDetail (NOLOCK)  
      WHERE  LoadplanDetail.loadkey = @cLoadKey   
      AND NOT Exists ( SELECT 1
         FROM PickHeader PH (NOLOCK)  
         WHERE PH.OrderKey = LoadplanDetail.Orderkey )
      
      SELECT @nPS_count = 0
       
      IF @nPS_count is null
         SET @nPS_count = 0
         
      IF @nPS_count > 0
      BEGIN 
         BEGIN TRAN    
         EXECUTE nspg_GetKey
 			'PICKSLIP',
 			9,
 			@cBatch_PickSlipno	OUTPUT,
 			@bSuccess				OUTPUT,
 			@nErr					OUTPUT,
 			@cErrmsg				OUTPUT,
         0,
         @nPS_count            
         IF NOT @bSuccess = 1
         BEGIN
            SELECT @nContinue = 3
            SELECT @nErr = 38014
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Getkey (ispLPPK04)' 
            GOTO QUIT_SP
         END    
         ELSE
         BEGIN 
            COMMIT TRAN
         END   
         SET @nBatch_PickSlipno = CAST(@cBatch_PickSlipno as INT)
      END
   END   	  
     
   BEGIN TRAN
   
   DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT OrderKey   
   FROM   LoadplanDetail (NOLOCK)  
   WHERE  loadkey = @cLoadKey   
  
   OPEN CUR_ORDER  
  
   FETCH NEXT FROM CUR_ORDER INTO @cOrderKey   
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @cPickSlipno = ''      
      SELECT @cPickSlipno = PickheaderKey  
      FROM PickHeader (NOLOCK)  
      WHERE OrderKey = @cOrderKey      
        
      -- Create Pickheader      
      IF ISNULL(@cPickSlipno ,'') = ''  
      BEGIN  
         
         SET @cBatch_PickSlipno = RTrim(LTrim(CONVERT(NVARCHAR(9),@nBatch_PickSlipno))) 
         SET @cBatch_PickSlipno = RIGHT(RTrim(Replicate('0',9) + @cBatch_PickSlipno),9)
             
         SELECT @cPickslipno = 'P'+@cBatch_PickSlipno      

         Set @nBatch_PickSlipno = @nBatch_PickSlipno + 1                       
                                         
  --       EXECUTE dbo.nspg_GetKey   
  --       'PICKSLIP',   9,   @cPickslipno OUTPUT,   @bSuccess OUTPUT,   @nErr OUTPUT,   @cErrmsg OUTPUT      
           
  --       SELECT @cPickslipno = 'P'+@cPickslipno      
                    
         INSERT INTO PICKHEADER  
                     (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)  
              VALUES (@cPickslipno , @cLoadKey, @cOrderKey, '0', 'D', '')              
      END 
      
      IF (SELECT COUNT(1) FROM PICKINGINFO(NOLOCK) WHERE Pickslipno = @cPickslipno) = 0
      BEGIN
         INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
              VALUES (@cPickslipno ,GETDATE(),sUser_sName(), NULL)
      END
  
      UPDATE PICKDETAIL WITH (ROWLOCK)  
      SET    PickSlipNo = @cPickSlipNo  
            ,TrafficCop = NULL  
      WHERE  OrderKey = @cOrderKey       
       
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
 
      DELETE FROM #TMP_PICKSKU
 
      INSERT INTO #TMP_PICKSKU (Storerkey, Sku, Putawayzone, Qty, StdCube, StdNetWgt, Loc, Lot)
      SELECT PD.StorerKey, PD.SKU, L.Putawayzone, SUM(PD.Qty), CONVERT(DECIMAL(20,8),S.Stdcube) AS Stdcube, 
             CONVERT(DECIMAL(20,8),S.StdNetWgt) AS StdNetWgt, PD.Loc, PD.Lot
      FROM PICKDETAIL PD (NOLOCK)  
      JOIN SKU S (NOLOCK) ON (PD.Storerkey = S.Storerkey AND PD.Sku = S.Sku)
      JOIN LOC L (NOLOCK) ON (PD.Loc = L.Loc)
      WHERE PD.OrderKey = @cOrderKey 
      AND PD.Qty > 0   
      GROUP BY PD.StorerKey, PD.SKU, L.Putawayzone, S.Stdcube, PD.Loc, PD.Lot, S.StdNetWgt
          
      SELECT @nOrderCube = SUM(qty * stdcube),
             @nOrderNetWgt = SUM(qty * stdNetWgt)
      FROM #TMP_PICKSKU  
      
      SELECT @nSkuCube = 0, @nSkuNetWgt = 0
      SELECT @nCartonCube = 0, @nCartonNetWgt = 0
              
      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT StorerKey, SKU, Putawayzone, Qty, Stdcube, StdNetWgt, Loc, Lot
         FROM #TMP_PICKSKU (NOLOCK)  
         ORDER BY Putawayzone, Loc, SKU, Lot
        
      OPEN CUR_PICKDETAIL  
      
      SET @cPrevPutawayzone = ''
      FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @cPutawayzone, @nQty, @nStdCube, @nStdNetWgt, @cLoc, @cLot
      WHILE @@FETCH_STATUS<>-1  
      BEGIN  
      	 IF @cPrevPutawayzone <> @cPutawayzone
      	 BEGIN
      	    SELECT @nCartonCube = 0, @nCartonNetWgt = 0
      	 	SET @cPrevPutawayzone = @cPutawayzone
      	 END 
      	 
         SET @nSkuCube = @nStdCube * @nQty
         SET @nSkuNetWgt = @nStdNetWgt * @nQty
         WHILE  @nSkuCube > 0 AND @nSkuNetWgt > 0
         BEGIN
            IF ISNULL(@nCartonCube,0) <= 0 OR ISNULL(@nCartonNetWgt,0) <= 0 
            BEGIN                    
               SELECT TOP 1 @nCartonCube = CONVERT(DECIMAL(20,8),CZ.[Cube]),
                      @nCartonNetWgt = CONVERT(DECIMAL(20,8),CZ.MaxWeight), 
                      @cCartonType = CZ.Cartontype
               FROM CARTONIZATION CZ (NOLOCK)
               JOIN STORER S (NOLOCK) ON (CZ.CartonizationGroup = S.CartonGroup)
               WHERE S.Storerkey = @cStorerkey
               ORDER BY CZ.UseSequence
                              
               IF ISNULL(@nCartonCube,0) <= 0
               BEGIN
             	    SELECT @nContinue=3
                  SELECT @nErr = 38000
                  SELECT @cErrMsg = 'Cartonization Cube Not Yet Setup For ' + RTRIM(@cStorerkey)
                  GOTO QUIT_SP      
               END

               IF ISNULL(@nCartonNetWgt,0) <= 0
               BEGIN
             	    SELECT @nContinue=3
                  SELECT @nErr = 38010
                  SELECT @cErrMsg = 'Cartonization Weight Not Yet Setup For ' + RTRIM(@cStorerkey)
                  GOTO QUIT_SP      
               END

               IF ISNULL(@nCartonCube,0) < @nStdCube 
                  OR ISNULL(@nCartonNetWgt,0) < @nStdNetWgt
                  SET @cStdCubeWgtNotFit = 'Y'      
               ELSE 
                  SET @cStdCubeWgtNotFit = 'N'      

               -- New Carton Label               
               EXEC isp_GenUCCLabelNo
                    @cStorerKey,
                    @cLabelNo  OUTPUT,
                    @bSuccess  OUTPUT,
                    @nErr      OUTPUT,
                    @cErrMsg   OUTPUT
               
               IF @bsuccess = 0
               BEGIN
                  SELECT @nContinue = 3
                  GOTO QUIT_SP
               END                 
               
               IF ISNULL(@cLabelNo,'') = ''
               BEGIN
             	   SELECT @nContinue = 3
                  SELECT @nErr = 38020
                  SELECT @cErrMsg = 'Empty Label# generated' 
                  GOTO QUIT_SP      
               END               
            END

            IF @cStdCubeWgtNotFit = 'Y'
            BEGIN
               SET @nSkuCube = @nSkuCube - @nStdCube
               SET @nCartonCube = 0
               SET @nOrderCube = @nOrderCube - @nStdCube

               SET @nSkuNetWgt = @nSkuNetWgt - @nStdNetWgt
               SET @nCartonNetWgt = 0
               SET @nOrderNetWgt = @nOrderNetWgt - @nStdNetWgt
                         
               SET @nQty = @nQty - 1
               SET @nPackQty = 1
            END
            ELSE
            BEGIN         
               SET @nPackQty = 0
               WHILE @nCartonCube > 0 AND @nSkuCube > 0 
                     AND @nCartonNetWgt > 0 AND @nSkuNetWgt > 0
               BEGIN
                  IF @nCartonCube < @nStdCube
                     OR @nCartonNetWgt < @nStdNetWgt
                  BEGIN
                     SELECT @nCartonCube = 0, @nCartonNetWgt = 0                     
                     CONTINUE
                  END
                  SET @nSkuCube = @nSkuCube - @nStdCube
                  SET @nCartonCube = @nCartonCube - @nStdCube
                  SET @nOrderCube = @nOrderCube - @nStdCube  
                  
                  SET @nSkuNetWgt = @nSkuNetWgt - @nStdNetWgt
                  SET @nCartonNetWgt = @nCartonNetWgt - @nStdNetWgt
                  SET @nOrderNetWgt = @nOrderNetWgt - @nStdNetWgt  
                          
                  SET @nQty = @nQty - 1
                  SET @nPackQty = @nPackQty + 1        
               END
            END
                              
            -- CartonNo and LabelLineNo will be inserted by trigger    
            INSERT INTO PACKDETAIL     
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno, Refno2, UPC)    
            VALUES     
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU,   
                @nPackQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(),@cLoc, @cLot, @cCartonType)
            
            IF @@ERROR <> 0
            BEGIN
               SELECT @nContinue = 3
               SELECT @nErr = 38030
               SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Insert PackDetail Table (ispLPPK04)' 
               GOTO QUIT_SP
            END
         END                  
         FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @cPutawayzone, @nQty, @nStdCube, @nStdNetWgt, @cLoc, @cLot  
      END  
      CLOSE CUR_PICKDETAIL  
      DEALLOCATE CUR_PICKDETAIL      

      DELETE FROM PACKINFO WHERE PickSlipNo = @cPickSlipno
      
      INSERT INTO PACKINFO (Pickslipno, CartonNo, Cube, CartonType, Weight)
      SELECT PD.Pickslipno, PD.CartonNo, CZ.[Cube], CZ.CartonType, SUM(PD.Qty * SKU.StdNetWgt)
      FROM PACKDETAIL PD (NOLOCK)
      JOIN STORER S (NOLOCK) ON (PD.Storerkey = S.Storerkey)
      JOIN CARTONIZATION CZ (NOLOCK) ON (S.CartonGroup = CZ.CartonizationGroup AND PD.RefNo2 = CZ.CartonType)
      JOIN SKU (NOLOCK) ON (PD.Storerkey = PD.Storerkey AND PD.Sku = SKU.Sku)
      WHERE PD.Pickslipno = @cPickSlipNo
      GROUP BY PD.Pickslipno, PD.CartonNo, CZ.[Cube], CZ.CartonType
        
      SKIP_ORDER:
        
      FETCH NEXT FROM CUR_ORDER INTO @cOrderKey      
   END   
   CLOSE CUR_ORDER  
   DEALLOCATE CUR_ORDER 

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   WHILE @@TRANCOUNT < @nStartTCnt
   BEGIN
      BEGIN TRAN
   END
   
   QUIT_SP:
   
	IF @nContinue=3  -- Error Occured - Process AND Return
	BEGIN
	   SELECT @bSuccess = 0
		IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @nStartTCnt
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
		EXECUTE dbo.nsp_LogError @nErr, @cErrmsg, 'ispLPPK04'		
		RAISERROR (@cErrmsg, 16, 1) WITH SETERROR    -- SQL2012
		--RAISERROR @nErr @cErrmsg
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
END  

GO