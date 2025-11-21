SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispLPPK11                                          */  
/* Creation Date: 07-Sep-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20704 - [CN] Dr.Jart+ Auto GenPackFromPicked            */ 
/*                                                                      */
/* Called By: Load Plan (Storerconfig.Configkey = 'LPGENPACKFROMPICKED' */ 
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 07-Sep-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE PROC [dbo].[ispLPPK11]
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
           @cCartonGroup NVARCHAR(10), 
           @cLabelNo NVARCHAR(20),
           @cDiscreteOrConso NCHAR(1),
           @cBatch_PickSlipno NVARCHAR(10),
           @nBatch_PickSlipno INT,           
           @nPS_count   INT,
           @cBatch_LabelNo NVARCHAR(20),
           @nBatch_LabelNo BIGINT,           
           @nLabelNo_count INT
   
   DECLARE @c_Facility        NVARCHAR(5)
         , @c_SValue          NVARCHAR(50)
         , @c_Option1         NVARCHAR(50) = ''  
         , @c_Option2         NVARCHAR(50) = ''  
         , @c_Option3         NVARCHAR(50) = ''  
         , @c_Option4         NVARCHAR(50) = ''  
         , @c_Option5         NVARCHAR(4000) = ''
         , @c_AutoPackConfirm NVARCHAR(10) = 'N'
         , @c_PackLabelToOrd  NVARCHAR(10) = ''
         , @cLottable09       NVARCHAR(50) = ''
         , @nCasecnt          INT = 0
         , @nCartonNo         INT = 0
         , @nLabelLineNo      INT = 0
         , @cLabelLineNo      NVARCHAR(10)
                   
   SELECT @nContinue = 1, @nStartTCnt = @@TRANCOUNT, @nErr = 0, @cErrMsg = ''
   SELECT @cDiscreteOrConso = 'D', @cPickSlipno = '', @cLabelNo = ''   
                  
   IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
             JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
             JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.Orderkey = PD.Orderkey
             WHERE PD.Status='4' AND PD.Qty > 0 
             AND  LPD.LoadKey = @cLoadKey)
   BEGIN
       SELECT @nContinue=3
       SELECT @nErr = 38002
       SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': Found Short Pick with Qty > 0 '
       GOTO QUIT_SP 
   END
   
   SELECT @cPickSlipno = Pickheaderkey
   FROM PICKHEADER (NOLOCK)
   WHERE ExternOrderkey = @cLoadKey
   AND ISNULL(Orderkey,'') = ''
   
   IF ISNULL(@cPickSlipno,'') <> ''
   BEGIN
        SELECT @cDiscreteOrConso = 'C'
        
        SELECT TOP 1 @cLabelNo = LabelNo
        FROM PACKDETAIL (NOLOCK)
        WHERE Pickslipno = @cPickSlipno
        
        IF ISNULL(@cLabelNo,'') <> ''
        BEGIN
          SELECT @nContinue=3
          SELECT @nErr = 38003
          SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': This Load Plan Already Started Consolidated Packing at Pick Slip# ' + ISNULL(@cPickSlipno,'')
          GOTO QUIT_SP
      END                 
   END
   
   SELECT TOP 1 @cStorerkey = OH.Storerkey
              , @c_Facility = OH.Facility
   FROM ORDERS OH (NOLOCK)
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   WHERE LPD.Loadkey = @cLoadKey

   EXEC nspGetRight  
      @c_Facility           -- facility  
   ,  @cStorerkey           -- Storerkey  
   ,  NULL                  -- Sku  
   ,  'LPGENPACKFROMPICKED' -- Configkey  
   ,  @bSuccess                  OUTPUT   
   ,  @c_SValue                  OUTPUT   
   ,  @nErr                      OUTPUT   
   ,  @cErrMsg                   OUTPUT 
   ,  @c_Option1                 OUTPUT
   ,  @c_Option2                 OUTPUT
   ,  @c_Option3                 OUTPUT
   ,  @c_Option4                 OUTPUT
   ,  @c_Option5                 OUTPUT
   
   IF @bSuccess <> 1
   BEGIN
      SET @nContinue = 3
      SET @nErr = 38013 
      SET @cErrMsg='NSQL'+CONVERT(char(5),@nErr)+': Error Executing nspGetRight. (ispLPPK11)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@cErrMsg),'') + ' ) ' 
      GOTO QUIT_SP
   END

   SELECT @c_AutoPackConfirm = dbo.fnc_GetParamValueFromString('@c_AutoPackConfirm', @c_Option5, 'N')  

   IF ISNULL(@c_AutoPackConfirm, '') = ''
      SET @c_AutoPackConfirm = 'N' 

   EXEC nspGetRight 
      @c_Facility                -- facility
   ,  @cStorerkey                -- Storerkey
   ,  NULL                       -- Sku
   ,  'AssignPackLabelToOrdCfg'  -- Configkey
   ,  @bSuccess           OUTPUT 
   ,  @c_PackLabelToOrd   OUTPUT 
   ,  @nErr               OUTPUT 
   ,  @cErrMsg            OUTPUT

   IF @bSuccess <> 1
   BEGIN
      SET @nContinue = 3
      SET @nErr = 38014 
      SET @cErrMsg='NSQL'+CONVERT(char(5),@nErr)+': Error Executing nspGetRight. (ispLPPK11)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@cErrMsg),'') + ' ) ' 
      GOTO QUIT_SP
   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
      
   IF @cDiscreteOrConso = 'D'
   BEGIN  
      SELECT @nPS_count = 0

      SELECT @nPS_count = Count(1)   
      FROM   LoadplanDetail (NOLOCK)  
      WHERE  LoadplanDetail.loadkey = @cLoadKey   
      AND NOT EXISTS ( SELECT 1
                       FROM PickHeader PH (NOLOCK)  
                       WHERE PH.OrderKey = LoadplanDetail.Orderkey )
             
      IF @nPS_count is null
         SET @nPS_count = 0
         
      IF @nPS_count > 0
      BEGIN 
         BEGIN TRAN    
         EXECUTE nspg_GetKey
                'PICKSLIP',
                9,
                @cBatch_PickSlipno   OUTPUT,
                @bSuccess            OUTPUT,
                @nErr               OUTPUT,
                @cErrmsg            OUTPUT,
                0,
                @nPS_count            
         IF NOT @bSuccess = 1
         BEGIN
            SELECT @nContinue = 3
            SELECT @nErr = 38014
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Getkey (ispLPPK11)' 
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
   FROM LoadplanDetail (NOLOCK)  
   WHERE Loadkey = @cLoadKey   
  
   OPEN CUR_ORDER  
  
   FETCH NEXT FROM CUR_ORDER INTO @cOrderKey   
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF @cDiscreteOrConso = 'D'
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
                 
            --EXECUTE dbo.nspg_GetKey   
            --'PICKSLIP',   9,   @cPickslipno OUTPUT,   @bSuccess OUTPUT,   @nErr OUTPUT,   @cErrmsg OUTPUT      
              
            SELECT @cPickslipno = 'P' + @cBatch_PickSlipno      
                       
            INSERT INTO PICKHEADER  
                        (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)  
            VALUES (@cPickslipno , @cLoadKey, @cOrderKey, '0', '3', '')        

            Set @nBatch_PickSlipno = @nBatch_PickSlipno + 1                       
         END 
         
         IF (SELECT COUNT(1) FROM PICKINGINFO(NOLOCK) WHERE Pickslipno = @cPickslipno) = 0
         BEGIN
            INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
            VALUES (@cPickslipno ,GETDATE(),sUser_sName(), NULL)
         END         
      END     
 
      UPDATE PICKDETAIL WITH (ROWLOCK)  
      SET    PickSlipNo = @cPickSlipNo  
            ,TrafficCop = NULL  
      WHERE  OrderKey = @cOrderKey  

      -- Create packheader if not exists      
      IF (SELECT COUNT(1) FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) = 0      
      BEGIN      
          IF @cDiscreteOrConso = 'C'
          BEGIN
            INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)      
            SELECT TOP 1 O.Route, '', '', O.LoadKey, '',O.Storerkey, @cPickSlipNo       
            FROM  PICKHEADER PH (NOLOCK)      
            JOIN  Orders O (NOLOCK) ON (PH.ExternOrderkey = O.Loadkey)      
            WHERE PH.PickHeaderKey = @cPickSlipNo
         END  
         ELSE
         BEGIN
            INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)      
            SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo       
            FROM  PICKHEADER PH (NOLOCK)      
            JOIN  Orders O (NOLOCK) ON (PH.Orderkey = O.Orderkey)      
            WHERE PH.PickHeaderKey = @cPickSlipNo
         END
      END       
      ELSE
      BEGIN
         IF @cDiscreteOrConso = 'C'
         BEGIN
            IF (SELECT COUNT(1) FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND RefNo2 = @cOrderkey) > 0 
               GOTO SKIP_ORDER
         END           
         ELSE 
         BEGIN
            IF (SELECT COUNT(1) FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) > 0 
               GOTO SKIP_ORDER
         END
      END
      
      SET @nCartonNo = 1

      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         WITH CTE1 AS
         (
            SELECT PD.StorerKey, PD.SKU, LA.Lottable09, SUM(PD.QTY) AS Qty, MAX(P.CaseCnt) AS CaseCnt
                 , CASE WHEN SUM(PD.Qty) > MAX(P.Casecnt) THEN MAX(P.Casecnt) ELSE 0 END AS MaxQty
                 , CASE WHEN SUM(PD.Qty) > MAX(P.Casecnt) THEN CAST(SUM(PD.Qty) / MAX(P.Casecnt) AS INT) ELSE 0 END AS WHOLES 
                 , CASE WHEN SUM(PD.Qty) > MAX(P.Casecnt) THEN SUM(PD.Qty) % CAST(MAX(P.Casecnt) AS INT) ELSE SUM(PD.Qty) END AS PARTIALS
            FROM PICKDETAIL PD WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = PD.Lot
            JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU
            JOIN PACK P WITH (NOLOCK) ON P.PackKey = S.PACKKey
            WHERE PD.OrderKey = @cOrderKey
            GROUP BY PD.StorerKey, PD.SKU, LA.Lottable09
         ) 
         ,CTE2 AS 
         (
             SELECT Storerkey, SKU, Lottable09, Casecnt, MaxQty, WHOLES, 'BASE ' AS Remark
             FROM CTE1
             UNION ALL
             SELECT Storerkey, SKU, Lottable09, Casecnt, MaxQty, WHOLES - 1, 'RECUR' AS Remark
             FROM CTE2 
             WHERE WHOLES > 1
         ) 
         SELECT Storerkey, SKU, Lottable09, Casecnt, MaxQty AS QuantityRequired
         FROM CTE2
         WHERE MaxQty > 0
         UNION ALL
         SELECT Storerkey, SKU, Lottable09, Casecnt, PARTIALS AS QuantityRequired
         FROM CTE1 
         WHERE PARTIALS > 0
         ORDER BY Storerkey ASC, SKU ASC, Lottable09 ASC, QuantityRequired DESC
         OPTION (MAXRECURSION 0)
        
      OPEN CUR_PICKDETAIL
      
      IF @cDiscreteOrConso = 'D'
      BEGIN
        SELECT @cLabelNo = ''   
      END
                       
      FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @cLottable09, @nCasecnt, @nQty
      WHILE @@FETCH_STATUS<>-1  
      BEGIN           
         SET @cLabelNo = ''
         SET @nLabelLineNo = 0  
         
         EXEC isp_GenUCCLabelNo_Std  
            @cPickslipNo  = @cPickslipno,  
            @nCartonNo    = @nCartonNo,  
            @cLabelNo     = @cLabelNo OUTPUT,
            @b_success    = @bSuccess OUTPUT,
            @n_err        = @nErr OUTPUT,  
            @c_errmsg     = @cErrmsg OUTPUT  
            
         IF @bSuccess <> 1  
         BEGIN
            SET @nContinue = 3 
            GOTO QUIT_SP
         END
         
         SET @nLabelLineNo = @nLabelLineNo + 1  
         SET @cLabelLineNo = RIGHT('00000' + RTRIM(CAST(@nLabelLineNo AS NVARCHAR)),5)     
                                        
         INSERT INTO PACKDETAIL     
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno, RefNo2)    
         VALUES     
            (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLineNo, @cStorerKey, @cSKU,   
             @nQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cLottable09, @cOrderKey)
         
         IF @@ERROR <> 0
         BEGIN
            SELECT @nContinue = 3
            SELECT @nErr = 38004
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Insert PackDetail Table (ispLPPK11)' 
            GOTO QUIT_SP
         END

         INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, [Weight], Qty, [Cube], CartonType)
         SELECT @cPickslipno, @nCartonNo, (S.STDGrossWgt * @nQty), @nQty, (S.STDCUBE * @nQty), 'A' 
         FROM SKU S (NOLOCK)
         WHERE S.StorerKey = @cStorerKey AND S.Sku = @cSKU

         IF @@ERROR <> 0
         BEGIN
            SELECT @nContinue = 3
            SELECT @nErr = 38009
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Insert Packinfo Table (ispLPPK11)' 
            GOTO QUIT_SP
         END
         
         SET @nCartonNo = @nCartonNo + 1

         FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @cLottable09, @nCasecnt, @nQty  
      END  
      CLOSE CUR_PICKDETAIL  
      DEALLOCATE CUR_PICKDETAIL      

      SKIP_ORDER:
 
      IF @c_AutoPackConfirm = 'Y' AND @cDiscreteOrConso = 'D'
      BEGIN
         UPDATE PACKHEADER WITH (ROWLOCK) 
         SET [Status] = '9'
         WHERE Pickslipno = @cPickSlipNo
         AND [Status] <> '9'
         
         IF @@ERROR <> 0
         BEGIN
            SELECT @nContinue = 3
            SELECT @nErr = 38005
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Update PackHeader Table (ispLPPK11)'
            GOTO QUIT_SP
         END

         IF @c_PackLabelToOrd = '1'
         BEGIN
            EXEC isp_AssignPackLabelToOrderByLoad
                  @c_PickSlipNo = @cPickSlipNo
               ,  @b_Success    = @bSuccess  OUTPUT
               ,  @n_Err        = @nErr      OUTPUT
               ,  @c_ErrMsg     = @cErrMsg   OUTPUT
         
            IF @bSuccess <> 1
            BEGIN
               SET @nContinue = 3
               SET @nErr = 38008
               SET @cErrMsg = 'NSQL' +  CONVERT(CHAR(5),@nErr)  + ':'  
                              + 'Error Executing isp_AssignPackLabelToOrderByLoad.(ispLPPK11)'
               GOTO QUIT_SP
            END
         END
      END
        
      FETCH NEXT FROM CUR_ORDER INTO @cOrderKey      
   END   
   CLOSE CUR_ORDER  
   DEALLOCATE CUR_ORDER 

   IF @c_AutoPackConfirm = 'Y' AND @cDiscreteOrConso = 'C'
   BEGIN
      UPDATE PACKHEADER WITH (ROWLOCK) 
      SET [Status] = '9'
      WHERE Pickslipno = @cPickSlipNo
      AND [Status] <> '9'
      
      IF @@ERROR <> 0
      BEGIN
         SELECT @nContinue = 3
         SELECT @nErr = 38006
         SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Update PackHeader Table (ispLPPK11)'
         GOTO QUIT_SP
      END

      IF @c_PackLabelToOrd = '1'
      BEGIN
         EXEC isp_AssignPackLabelToOrderByLoad
               @c_PickSlipNo = @cPickSlipNo
            ,  @b_Success    = @bSuccess  OUTPUT
            ,  @n_Err        = @nErr      OUTPUT
            ,  @c_ErrMsg     = @cErrMsg   OUTPUT
      
         IF @bSuccess <> 1
         BEGIN
            SET @nContinue = 3
            SET @nErr = 38007
            SET @cErrMsg = 'NSQL' +  CONVERT(CHAR(5),@nErr)  + ':'  
                           + 'Error Executing isp_AssignPackLabelToOrderByLoad.(ispLPPK11)'
            GOTO QUIT_SP
         END
      END
   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   WHILE @@TRANCOUNT < @nStartTCnt
   BEGIN
      BEGIN TRAN
   END

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_ORDER') IN (0 , 1)
   BEGIN
      CLOSE CUR_ORDER
      DEALLOCATE CUR_ORDER   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PICKDETAIL') IN (0 , 1)
   BEGIN
      CLOSE CUR_PICKDETAIL
      DEALLOCATE CUR_PICKDETAIL   
   END
   
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
      EXECUTE dbo.nsp_LogError @nErr, @cErrmsg, 'ispLPPK11'
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