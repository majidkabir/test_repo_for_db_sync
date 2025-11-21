SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispLPPK05                                          */
/* Creation Date: 19-Jul-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#283731-CN PUMA Dummy Packing                            */   
/*                                                                      */
/* Called By: Load Plan                                                 */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 13-Nov-2013  TLTING   1.1  Blocking Tune                             */
/* 13-Apr-2014  TLTING   1.2  SQl2012 Bug fix                           */
/* 19-Jan-2015  NJOW01   1.3  Fix label no bug                          */
/* 22-Jan-2015  NJOW02   1.4  331529-Add 20 digits UCC label no by      */
/*                            storerconfig GenUCCLabelNoConfig          */
/* 08-Aug-2022  WLChooi  1.5  WMS-20446 - Add Packconfirm logic (WL01)  */
/* 08-Aug-2022  WLChooi  1.5  DevOps Combine Script                     */
/* 02-Jun-2023  NJOW03   1.6  WMS-22727 insert packinfo table           */
/************************************************************************/

CREATE   PROC [dbo].[ispLPPK05]
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
           @nLabelNo_count INT,
           @cDocType NVARCHAR(1), --NJOW03
           @cECOM_SINGLE_Flag NVARCHAR(1), --NJOW03
           @cTrackingNo NVARCHAR(40), --NJOW03
           @nCartonNo INT --NJOW03
           
   DECLARE @cGenUCCLabelNoConfig NVARCHAR(10),
           @cIdentifier    NVARCHAR(2),
           @cPacktype      NVARCHAR(1),
           @cVAT           NVARCHAR(18),
           @cPackNo_Long   NVARCHAR(250),
           @cKeyname       NVARCHAR(30),
           @nCheckDigit    INT,
           @nTotalCnt      INT,
           @nTotalOddCnt   INT,
           @nTotalEvenCnt  INT,
           @nAdd           INT,
           @nDivide        INT,
           @nRemain        INT,
           @nOddCnt        INT,
           @nEvenCnt       INT,
           @nOdd           INT,
           @nEven          INT
   
   --WL01 S
   DECLARE @c_Facility        NVARCHAR(5)
         , @c_SValue          NVARCHAR(50)
         , @c_Option1         NVARCHAR(50) = ''  
         , @c_Option2         NVARCHAR(50) = ''  
         , @c_Option3         NVARCHAR(50) = ''  
         , @c_Option4         NVARCHAR(50) = ''  
         , @c_Option5         NVARCHAR(4000) = ''
         , @c_AutoPackConfirm NVARCHAR(10) = 'N'
         , @c_PackLabelToOrd  NVARCHAR(10) = ''
   --WL01 E
                                             
   SELECT @nContinue=1, @nStartTCnt=@@TRANCOUNT, @nErr = 0, @cErrMsg = ''
   SELECT @cDiscreteOrConso = 'D', @cPickSlipno = '', @cLabelNo = ''   
                  
   IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
             JOIN  ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
             WHERE PD.Status='4' AND PD.Qty > 0 
              AND  O.LoadKey = @cLoadKey)
   BEGIN
       SELECT @nContinue=3
       SELECT @nErr = 38002
       SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': Found Short Pick with Qty > 0 '
       GOTO QUIT_SP 
   END
   
   SELECT @cPickSlipno = Pickheaderkey
   FROM PICKHEADER (NOLOCK)
   WHERE ExternOrderkey = @cLoadKey
   AND ISNULL(Orderkey,'')=''
   
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
   
   --WL01 S
   --SELECT TOP 1 @cStorerkey = Storerkey
   --FROM ORDERS(NOLOCK)
   --WHERE Loadkey = @cLoadKey

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
      SET @cErrMsg='NSQL'+CONVERT(char(5),@nErr)+': Error Executing nspGetRight. (ispLPPK05)' 
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
      SET @cErrMsg='NSQL'+CONVERT(char(5),@nErr)+': Error Executing nspGetRight. (ispLPPK05)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@cErrMsg),'') + ' ) ' 
      GOTO QUIT_SP
   END
   --WL01 E

   EXEC nspGetRight  
     @c_Facility  = NULL,  
     @c_StorerKey = @cStorerKey,  
     @c_sku       = NULL,  
     @c_ConfigKey = 'GenUCCLabelNoConfig',  
     @b_Success   = @bSuccess               OUTPUT,  
     @c_authority = @cGenUCCLabelNoConfig   OUTPUT,  
     @n_err       = @nErr                   OUTPUT,  
     @c_errmsg    = @cErrMsg                OUTPUT  

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
      AND NOT Exists ( SELECT 1
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
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Getkey (ispLPPK05)' 
            GOTO QUIT_SP
         END    
         ELSE
         BEGIN 
            COMMIT TRAN
         END   
         SET @nBatch_PickSlipno = CAST(@cBatch_PickSlipno as INT)
      END
      
      SELECT @nLabelNo_count = 0
   
      SELECT @nLabelNo_count = Count(DISTINCT PD.Orderkey)   
      FROM   LoadplanDetail (NOLOCK)  
      JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = LoadplanDetail.Orderkey
      WHERE  LoadplanDetail.loadkey = @cLoadKey   
      AND NOT Exists ( SELECT 1
                     FROM PackHeader PH (NOLOCK)  
                     JOIN PackDetail PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno 
                     WHERE PH.OrderKey = LoadplanDetail.Orderkey )
             
      IF @nLabelNo_count is null
         SET @nLabelNo_count = 0         
   END                 
   ELSE
   BEGIN --CONSO
      SELECT @nLabelNo_count = 1   
   END
      
   IF @nLabelNo_count > 0 
   BEGIN       
      BEGIN TRAN   
         
      IF @cGenUCCLabelNoConfig = '1'
      BEGIN
         SET @cIdentifier = '00'
         SET @cPacktype = '0'  
         
         SELECT @cVAT = ISNULL(Vat,'')
         FROM Storer WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
          
         IF ISNULL(@cVAT,'') = ''
            SET @cVAT = '000000000'
         
         IF LEN(@cVAT) <> 9 
            SET @cVAT = RIGHT('000000000' + RTRIM(LTRIM(@cVAT)), 9)
          
         SELECT @cPackNo_Long = Long 
         FROM  CODELKUP (NOLOCK)
         WHERE ListName = 'PACKNO'
         AND Code = @cStorerkey
         
         IF ISNULL(@cPackNo_Long,'') = ''
            SET @cKeyname = 'TBLPackNo'
         ELSE
            SET @cKeyname = 'PackNo' + LTRIM(RTRIM(ISNULL(@cPackNo_Long,'')))

         EXECUTE nspg_GetKey
             @ckeyname,
             7,
             @cBatch_LabelNo   OUTPUT,
             @bSuccess         OUTPUT,
             @nErr             OUTPUT,
             @cErrmsg          OUTPUT,
             0,
             @nLabelNo_count                      
       END
       ELSE
       BEGIN
         EXECUTE nspg_GetKey
             'PACKNO',
             10,
             @cBatch_LabelNo   OUTPUT,
             @bSuccess         OUTPUT,
             @nErr             OUTPUT,
             @cErrmsg          OUTPUT,
             0,
             @nLabelNo_count                     
      END
      
      IF NOT @bSuccess = 1
      BEGIN
         SELECT @nContinue = 3
         SELECT @nErr = 38015
         SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Getkey PACKNO (ispLPPK05)' 
         GOTO QUIT_SP
      END    
      ELSE
      BEGIN 
         COMMIT TRAN
      END   
      SET @nBatch_LabelNo = CAST(@cBatch_LabelNo as BIGINT)
   END      
    
   BEGIN TRAN
   
   DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT O.OrderKey, 
          O.Doctype, O.ECOM_SINGLE_Flag, O.TrackingNo    --NJOW03   
   FROM   LoadplanDetail LPD (NOLOCK)  
   JOIN   Orders O (NOLOCK) ON LPD.Orderkey = O.Orderkey
   WHERE  LPD.loadkey = @cLoadKey   
  
   OPEN CUR_ORDER  
  
   FETCH NEXT FROM CUR_ORDER INTO @cOrderKey, @cDocType, @cECOM_SINGLE_Flag, @cTrackingNo --NJOW03   
  
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
              
            SELECT @cPickslipno = 'P'+@cBatch_PickSlipno      
                       
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
            IF (SELECT COUNT(1) FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND refno = @cOrderkey) > 0 
               GOTO SKIP_ORDER
         END           
         ELSE 
         BEGIN
            IF (SELECT COUNT(1) FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) > 0 
               GOTO SKIP_ORDER
         END
      END
                       
      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT StorerKey, SKU, SUM(QTY)  
         FROM   PICKDETAIL p WITH (NOLOCK)  
         WHERE  p.OrderKey = @cOrderKey   
         AND    P.Qty > 0   
         GROUP BY StorerKey, SKU  
        
      OPEN CUR_PICKDETAIL
      
      IF @cDiscreteOrConso = 'D'
      BEGIN
        SELECT @cLabelNo = ''   
      END
                       
      FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @nQty
      WHILE @@FETCH_STATUS<>-1  
      BEGIN           
          IF ISNULL(@cLabelNo,'') = '' 
         BEGIN
            IF @cGenUCCLabelNoConfig = '1'
            BEGIN
               SET @cBatch_LabelNo = RTrim(LTrim(CONVERT(NVARCHAR(7),@nBatch_LabelNo))) 
               SET @cBatch_LabelNo = RIGHT(RTrim(Replicate('0',7) + @cBatch_LabelNo),7)
               SET @cLabelNo = @cIdentifier + @cPacktype + RTRIM(ISNULL(@cVAT,'')) + RTRIM(@cBatch_LabelNo) --+ @nCheckDigit
                
               SET @nOdd = 1
               SET @nOddCnt = 0
               SET @nTotalOddCnt = 0
               SET @nTotalCnt = 0
               
               WHILE @nOdd <= 20 
               BEGIN
                  SET @nOddCnt = CAST(SUBSTRING(@cLabelNo, @nOdd, 1) AS INT)
                  SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
                  SET @nOdd = @nOdd + 2
               END
               
                SET @nTotalCnt = (@nTotalOddCnt * 3) 
         
               SET @nEven = 2
               SET @nEvenCnt = 0
               SET @nTotalEvenCnt = 0
               
               WHILE @nEven <= 20 
               BEGIN
                   SET @nEvenCnt = CAST(SUBSTRING(@cLabelNo, @nEven, 1) AS INT)
                   SET @nTotalEvenCnt = @nTotalEvenCnt + @nEvenCnt
                   SET @nEven = @nEven + 2
                END
               
                SET @nAdd = 0
                SET @nRemain = 0
                SET @nCheckDigit = 0
               
                SET @nAdd = @nTotalCnt + @nTotalEvenCnt
                SET @nRemain = @nAdd % 10
                SET @nCheckDigit = 10 - @nRemain
               
                IF @nCheckDigit = 10 
                     SET @nCheckDigit = 0
               
                SET @cLabelNo = ISNULL(RTRIM(@cLabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
            END
            ELSE
            BEGIN
               SET @cBatch_LabelNo = RTrim(LTrim(CONVERT(NVARCHAR(10),@nBatch_LabelNo))) 
               SET @cBatch_LabelNo = RIGHT(RTrim(Replicate('0',10) + @cBatch_LabelNo),10)
               SET @cLabelNo = @cBatch_LabelNo
            END
            
            Set @nBatch_LabelNo = @nBatch_LabelNo + 1              
         END
                                       
         -- CartonNo and LabelLineNo will be inserted by trigger    
         INSERT INTO PACKDETAIL     
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno)    
         VALUES     
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU,   
             @nQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cOrderKey)
         
         IF @@ERROR <> 0
         BEGIN
            SELECT @nContinue = 3
            SELECT @nErr = 38004
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Insert PackDetail Table (ispLPPK05)' 
            GOTO QUIT_SP
         END
                                             
         FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @nQty  
      END  
      CLOSE CUR_PICKDETAIL  
      DEALLOCATE CUR_PICKDETAIL      
      
      --NJOW03 S
      IF @cDiscreteOrConso = 'D' AND @cECOM_SINGLE_Flag = 'S' AND @cDocType = 'E'
      BEGIN         
         DECLARE CUR_PACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        	
            SELECT PD.CartonNo, SUM(PD.Qty)
            FROM PACKHEADER PH (NOLOCK) 
            JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
            LEFT JOIN PACKINFO PAI (NOLOCK) ON PH.Pickslipno = PAI.Pickslipno AND PD.CartonNo = PAI.CartonNo
            WHERE PH.Pickslipno = @cPickSlipNo
            GROUP BY PD.CartonNo
        
         OPEN CUR_PACK  
     
         FETCH NEXT FROM CUR_PACK INTO @nCartonNo, @nQty
      
         WHILE @@FETCH_STATUS = 0 AND @nContinue IN(1,2)
         BEGIN           
         	  IF EXISTS(SELECT 1 
         	            FROM PACKINFO(NOLOCK)
         	            WHERE Pickslipno = @cPickslipno
         	            AND CartonNo = @nCartonNo)
         	  BEGIN
         	     UPDATE PACKINFO 
         	     SET Qty = @nQty,
         	         TrackingNo = @cTrackingNo,
         	         TrafficCop = NULL
         	     WHERE Pickslipno = @cPickslipno
         	     AND CartonNo = @nCartonNo
         	  END
         	  ELSE   
         	  BEGIN             
         	     INSERT INTO PACKINFO (PickSlipNo, CartonNo, Weight, Cube, Qty, TrackingNo)
         	     VALUES (@cPickslipNo, @nCartonNo, 0, 0, @nQty, @cTrackingNo)
         	  END         	 
         	   
            FETCH NEXT FROM CUR_PACK INTO @nCartonNo, @nQty         	       
         END
         CLOSE CUR_PACK
         DEALLOCATE CUR_PACK               	
      END
      --NJOW03 E      
        
      SKIP_ORDER:

      --WL01 S
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
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Update PackHeader Table (ispLPPK05)'
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
                              + 'Error Executing isp_AssignPackLabelToOrderByLoad.(ispLPPK05)'
               GOTO QUIT_SP
            END
         END
      END
      --WL01 E
        
      FETCH NEXT FROM CUR_ORDER INTO @cOrderKey, @cDocType, @cECOM_SINGLE_Flag, @cTrackingNo --NJOW03      
   END   
   CLOSE CUR_ORDER  
   DEALLOCATE CUR_ORDER 

   --WL01 S
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
         SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Update PackHeader Table (ispLPPK05)'
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
                           + 'Error Executing isp_AssignPackLabelToOrderByLoad.(ispLPPK05)'
            GOTO QUIT_SP
         END
      END
   END
   --WL01 E

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
      EXECUTE dbo.nsp_LogError @nErr, @cErrmsg, 'ispLPPK05'      
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