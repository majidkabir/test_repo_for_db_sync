SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispLPPK06                                          */
/* Creation Date: 22-Apr-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-8584 HK Loreal Load generate packing                    */   
/*                                                                      */
/* Called By: Load Plan                                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispLPPK06]   
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
     
   DECLARE @c_Storerkey                    NVARCHAR(15),
           @c_Sku                          NVARCHAR(20),
           @n_Qty                          INT,
           @c_PickslipNo                   NVARCHAR(10),
           @n_CartonNo                     INT,
           @c_LabelNo                      NVARCHAR(20),
           @n_LabelLineNo                  INT,
           @c_LabelLineNo                  NVARCHAR(5)
                                               
   DECLARE @n_Continue   INT,
           @n_StartTCnt  INT,
           @n_debug      INT
   
 	 IF @nerr =  1
	    SET @n_debug = 1
	 ELSE
	    SET @n_debug = 0		 
                                                     
	 SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT, @nErr = 0, @cErrMsg = '', @bsuccess = 1 
	
	 IF @@TRANCOUNT = 0
	    BEGIN TRAN
         
   --Validation            
   IF @n_continue IN(1,2) 
   BEGIN
      IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
                JOIN  LOADPLANDETAIL LD WITH (NOLOCK) ON PD.Orderkey = LD.Orderkey 
                WHERE PD.Status='4' AND PD.Qty > 0 
                AND  LD.Loadkey = @cLoadKey)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @cerrmsg = CONVERT(NVARCHAR(250),@nerr), @nerr = 38010     
         SELECT @cerrmsg='NSQL'+CONVERT(NVARCHAR(5),@nerr)+': Found Short Pick with Qty > 0 (ispLPPK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@cerrmsg) + ' ) '           
         GOTO QUIT_SP 
      END
      
      IF EXISTS(SELECT 1 FROM LOADPLANDETAIL LPD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
                WHERE LPD.Loadkey = @cLoadkey
                AND O.Status <> '5')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @cerrmsg = CONVERT(NVARCHAR(250),@nerr), @nerr = 38015     
         SELECT @cerrmsg='NSQL'+CONVERT(NVARCHAR(5),@nerr)+': Found some orders are not picked(5). (ispLPPK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@cerrmsg) + ' ) '           
         GOTO QUIT_SP 
      END
                              
      IF NOT EXISTS(SELECT 1
                    FROM LOADPLAN L (NOLOCK)
                    LEFT JOIN PACKHEADER PH (NOLOCK) ON L.Loadkey = PH.Loadkey AND (PH.Orderkey IS NULL OR PH.Orderkey = '')
                    WHERE L.Loadkey = @cLoadkey
                    AND PH.Loadkey IS NULL)              	
      BEGIN
         SELECT @n_continue = 3  
         SELECT @cerrmsg = CONVERT(NVARCHAR(250),@nerr), @nerr = 38020     
         SELECT @cerrmsg='NSQL'+CONVERT(NVARCHAR(5),@nerr)+': No pick record found to generate pack. (ispLPPK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@cerrmsg) + ' ) '           
         GOTO QUIT_SP 
      END              
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  SELECT TOP 1 @c_Storerkey = Storerkey
   	  FROM LOADPLANDETAIL LPD (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
   	  AND LPD.Loadkey = @cLoadkey
   	  
      EXEC isp_CreatePickSlip
          @c_Orderkey             = '' 
         ,@c_Loadkey              = @cLoadkey
         ,@c_Wavekey              = ''
         ,@c_PickslipType         = 'LB' 
         ,@c_ConsolidateByLoad    = 'Y'   
         ,@c_Refkeylookup         = 'Y'
         ,@c_LinkPickSlipToPick   = 'N'  
         ,@c_AutoScanIn           = 'Y'
         ,@b_Success              = @bSuccess OUTPUT
         ,@n_Err                  = @nErr     OUTPUT 
         ,@c_ErrMsg               = @cErrMsg  OUTPUT
      
      IF @bSuccess <> 1
         SET @n_continue = 3
                                 
      SELECT TOP 1 @c_PickslipNo = PH.Pickheaderkey
      FROM PICKHEADER PH (NOLOCK)
      JOIN LOADPLAN LP (NOLOCK) ON PH.ExternOrderkey = LP.Loadkey 
      WHERE LP.Loadkey = @cLoadkey
      AND (PH.Orderkey IS NULL OR PH.Orderkey = '')

      INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)      
      SELECT TOP 1 O.Route, '', '', LPD.LoadKey, '',O.Storerkey, @c_PickSlipNo       
      FROM  PICKHEADER PH (NOLOCK)      
      JOIN  LOADPLANDETAIL LPD (NOLOCK) ON PH.ExternOrderkey = LPD.Loadkey
      JOIN  ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey    
      WHERE PH.PickHeaderKey = @c_PickSlipNo
               
      SET @nerr = @@ERROR
      
      IF @nerr <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @cerrmsg = CONVERT(NVARCHAR(250),@nerr), @nerr = 38030     
         SELECT @cerrmsg='NSQL'+CONVERT(NVARCHAR(5),@nerr)+': Insert Error On PACKHEADER Table. (ispLPPK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@cerrmsg) + ' ) '           
      END
      
      SET @c_LabelNo = ''
      SET @n_CartonNo = 1
      SET @n_LabelLineNo = 0
      
      EXEC isp_GenUCCLabelNo_Std
         @cPickslipNo  = @c_Pickslipno,
         @nCartonNo    = @n_CartonNo,
         @cLabelNo     = @c_LabelNo OUTPUT, 
         @b_success    = @bSuccess OUTPUT,
         @n_err        = @nerr OUTPUT,
         @c_errmsg     = @cerrmsg OUTPUT

      IF @bSuccess <> 1
         SET @n_continue = 3           

      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT P.SKU, SUM(P.Qty)  
         FROM PICKDETAIL P (NOLOCK)  
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON P.Orderkey = LPD.Orderkey
         WHERE LPD.Loadkey = @cLoadkey
         AND P.Qty > 0   
         GROUP BY P.SKU  
        
      OPEN CUR_PICKDETAIL
                                
      FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_Qty
      WHILE @@FETCH_STATUS<>-1  
      BEGIN        	
      	  SET @n_LabelLineNo = @n_LabelLineNo + 1
      	  SET @c_LabelLineNo = RIGHT('00000' + RTRIM(CAST(@n_LabelLineNo AS NVARCHAR)),5)
      	  
         INSERT INTO PACKDETAIL     
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)    
         VALUES     
            (@c_PickSlipNo, @n_CartonNo, @c_LabelNo, @c_LabelLineNo, @c_StorerKey, @c_SKU,   
             @n_Qty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE())            	

         SET @nerr = @@ERROR
         
         IF @nerr <> 0
         BEGIN
            SELECT @n_continue = 3  
            SELECT @cerrmsg = CONVERT(NVARCHAR(250),@nerr), @nerr = 38040     
            SELECT @cerrmsg='NSQL'+CONVERT(NVARCHAR(5),@nerr)+': Insert Error On PACKDETAIL Table. (ispLPPK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@cerrmsg) + ' ) '           
         END
                         
         FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_Qty
      END
      CLOSE CUR_PICKDETAIL 
      DEALLOCATE CUR_PICKDETAIL
      
      UPDATE PACKHEADER WITH (ROWLOCK)
      SET Status = '9'
      WHERE Pickslipno = @c_Pickslipno

      SET @nerr = @@ERROR
      
      IF @nerr <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @cerrmsg = CONVERT(NVARCHAR(250),@nerr), @nerr = 38050     
         SELECT @cerrmsg='NSQL'+CONVERT(NVARCHAR(5),@nerr)+': Update Error On PACKHEADER Table. (ispLPPK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@cerrmsg) + ' ) '           
      END                
      
      UPDATE PICKINGINFO WITH (ROWLOCK)
      SET ScanOutDate = GETDATE()
      WHERE PickslipNo = @c_PickslipNo
      AND (ScanOutDate IS NULL
          OR ScanOutDate = '1900-01-01')

      SET @nerr = @@ERROR
      
      IF @nerr <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @cerrmsg = CONVERT(NVARCHAR(250),@nerr), @nerr = 38060     
         SELECT @cerrmsg='NSQL'+CONVERT(NVARCHAR(5),@nerr)+': Update Error On PICKINGINFO Table. (ispLPPK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@cerrmsg) + ' ) '           
      END                   	
   END
   
   QUIT_SP:

	 IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	  SELECT @bSuccess = 0
	 	IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
	 	BEGIN
	 		ROLLBACK TRAN
	 	END
	 	ELSE
	 	BEGIN
	 		WHILE @@TRANCOUNT > @n_StartTCnt
	 		BEGIN
	 			COMMIT TRAN
	 		END
	 	END
	 	EXECUTE dbo.nsp_LogError @nErr, @cErrmsg, 'ispLPPK06'		
	 	RAISERROR (@cErrmsg, 16, 1) WITH SETERROR    -- SQL2012
	 	--RAISERROR @nErr @cErrmsg
	 	RETURN
	 END
	 ELSE
	 BEGIN
	  SELECT @bSuccess = 1
	 	WHILE @@TRANCOUNT > @n_StartTCnt
	 	BEGIN
	 		COMMIT TRAN
	 	END
	 	RETURN
	 END  
END  

GO