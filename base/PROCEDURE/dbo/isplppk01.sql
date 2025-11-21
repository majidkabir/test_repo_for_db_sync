SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispLPPK01                                          */
/* Creation Date: 04-Nov-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: 195377 - RCM Pick to Pack Process for paper Picks           */   
/*                                                                      */
/* Called By: Load Plan                                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 11-Nov-2010  Shong    1.1  Bug Fixing -- (SHONG01)                   */
/************************************************************************/

CREATE PROC [dbo].[ispLPPK01]   
   @cLoadKey    NVARCHAR(10),  
   @bSuccess    INT = 1  OUTPUT,
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
           @nToteNo     INT,  
           @nSKUCount   INT,
           @nContinue   INT,
           @nStartTCnt  INT  

	SELECT @nContinue=1, @nStartTCnt=@@TRANCOUNT
               
   -- Check is this load in Task Manager or not?
   IF EXISTS(SELECT 1 FROM TaskDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
   BEGIN
	   SELECT @nContinue=3
	   SELECT @nErr=32801
	   SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': Task Release, Cannot Generate Packing Information ' 
      GOTO QUIT_SP
   END
   
   IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
             JOIN  ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey -- (SHONG01)
             WHERE PD.Status='4' AND PD.Qty > 0 
              AND  O.LoadKey = @cLoadKey)
   BEGIN
	   SELECT @nContinue=3
	   SELECT @nErr=32802
	   SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': Found Short Pick with Qty > 0 '
      GOTO QUIT_SP 
   END 

   IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
             JOIN  ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey -- (SHONG01)
             WHERE PD.Status < '5' AND PD.Qty > 0 
              AND  O.LoadKey = @cLoadKey)
   BEGIN
	   SELECT @nContinue=3
	   SELECT @nErr=32803
	   SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': Pick Slip not Scan out yet'
      GOTO QUIT_SP 
   END 

   IF EXISTS(SELECT 1 FROM PackDetail PD WITH (NOLOCK) 
             JOIN  PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo 
             WHERE PD.Qty > 0 
              AND  PH.LoadKey = @cLoadKey)
   BEGIN
	   SELECT @nContinue=3
	   SELECT @nErr=32804
	   SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': Pack Records already generated!'
      GOTO QUIT_SP 
   END
  
   SET @nToteNo  = 1000  
  
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
      FROM   dbo.PickHeader WITH (NOLOCK)  
      WHERE  OrderKey = @cOrderKey      
        
      --PRINT @cOrderKey  
             
      -- Create Pickheader      
      IF ISNULL(@cPickSlipno ,'')=''  
      BEGIN  
         EXECUTE dbo.nspg_GetKey   
         'PICKSLIP',   9,   @cPickslipno OUTPUT,   @bSuccess OUTPUT,   @nErr OUTPUT,   @cErrmsg OUTPUT      
           
         SELECT @cPickslipno = 'P'+@cPickslipno      
                    
         INSERT INTO dbo.PICKHEADER  
           (  
             PickHeaderKey               ,ExternOrderKey         ,Orderkey               ,PickType  
            ,Zone                        ,TrafficCop  
           )  
         VALUES  
           (  
             @cPickslipno               ,@cLoadKey               ,@cOrderKey               ,'0'  
            ,'D'                        ,''              )     
      END -- ISNULL(@cPickSlipno ,'')=''  
  
      UPDATE dbo.PICKDETAIL WITH (ROWLOCK)  
      SET    PickSlipNo = @cPickSlipNo  
            ,TrafficCop = NULL  
      WHERE  OrderKey = @cOrderKey       
       
      -- Create packheader if not exists      
      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)      
      BEGIN      
         INSERT INTO dbo.PackHeader       
         (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)      
         SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo       
         FROM  dbo.PickHeader PH WITH (NOLOCK)      
         JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)      
         WHERE PH.PickHeaderKey = @cPickSlipNo  
      END       
        
      SET @nToteNo = @nToteNo + 1  
      SET @nSKUCount = 0     
        
      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT StorerKey, SKU, SUM(QTY)  
      FROM   PICKDETAIL p WITH (NOLOCK)  
      WHERE  p.OrderKey = @cOrderKey   
      AND    P.Qty > 0   
      GROUP BY StorerKey, SKU  
        
      OPEN CUR_PICKDETAIL  
        
      FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @nQty   
      WHILE @@FETCH_STATUS<>-1  
      BEGIN  
         -- Create packdetail    
         -- CartonNo and LabelLineNo will be inserted by trigger    
         IF NOT EXISTS(SELECT 1 FROM dbo.PackDetail pd WITH (NOLOCK)   
                       WHERE pd.PickSlipNo = @cPickSlipNo   
                       AND   pd.StorerKey = @cStorerKey    
                       AND   pd.sku = @cSKU)  
         BEGIN  
              
            INSERT INTO dbo.PackDetail     
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID)    
            VALUES     
               (@cPickSlipNo, 0, CAST(@nToteNo AS NVARCHAR(4)), '00000', @cStorerKey, @cSKU,   
                @nQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), CAST(@nToteNo AS NVARCHAR(4)))         
           
            SET @nSKUCount = @nSKUCount + 1  
              
            IF @nSKUCount >= 10  
            BEGIN  
               SET @nToteNo = @nToteNo + 1  
               SET @nSKUCount = 0   
            END   
   
         END  
         FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @nQty  
      END  
      CLOSE CUR_PICKDETAIL  
      DEALLOCATE CUR_PICKDETAIL      
        
      FETCH NEXT FROM CUR_ORDER INTO @cOrderKey      
   END   
   CLOSE CUR_ORDER  
   DEALLOCATE CUR_ORDER 

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
		EXECUTE dbo.nsp_LogError @nErr, @cErrmsg, 'ispLPPK01'		
		RAISERROR (@cErrmsg, 16, 1) WITH SETERROR    -- SQL2012
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