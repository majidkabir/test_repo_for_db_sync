SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/***************************************************************************/      
/* Stored Procedure: ispPAKCF09                                            */      
/* Creation Date: 25-JAN-2019                                              */      
/* Copyright: LF Logistics                                                 */      
/* Written by: Wan                                                         */      
/*                                                                         */      
/* Purpose: WMS-7669 - [CN] Doterra - Doterra ECOM Packing_CR.             */      
/*        :                                                                */      
/*                                                                         */      
/* Called By:                                                              */      
/*                                                                         */      
/*                                                                         */      
/* PVCS Version: 1.3                                                       */      
/*                                                                         */      
/* Version: 7.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */      
/* 12-03-2019   CSCHONG 1.1   WMS-8292-CN_Ecom-Packing_For JD_CR (CS01)    */  
/* 09-04-2021   Wan01   1.2   WMS-16026 - PB-Standardize TrackingNo        */
/* 27-05-2022   WLChooi 1.3   DevOps Combine Script                        */
/* 27-05-2022   WLChooi 1.3   WMS-19766 - Get Keyname filter UDF05 (WL01)  */
/* 08-03-2023   NJOW01  1.4   Fix - Update new labelno to packserialno     */
/***************************************************************************/        
CREATE   PROC [dbo].[ispPAKCF09]        
(     @c_PickSlipNo  NVARCHAR(10)         
  ,   @c_Storerkey   NVARCHAR(15)      
  ,   @b_Success     INT           OUTPUT      
  ,   @n_Err         INT           OUTPUT      
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT         
)        
AS        
BEGIN        
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE @b_Debug           INT      
         , @n_Continue        INT       
         , @n_StartTCnt       INT       
      
         , @c_Orderkey        NVARCHAR(10) = ''      
         , @c_PackStatus      NVARCHAR(10) = ''      
         , @n_CartonNo        INT      
         , @c_LabelLine       NVARCHAR(5)  = ''      
         , @c_SerialNo        NVARCHAR(30) = ''      
         , @c_SerialNoKey     NVARCHAR(10) = ''      
         , @c_TotalCtn        NVARCHAR(10)      --(CS01)    
         , @c_OHTrackingNo    NVARCHAR(30)      --(CS01)    
         , @c_TrackingNo      NVARCHAR(30)      --(CS01)    
         , @c_Shipperkey      NVARCHAR(30)      --(CS01)    
         , @c_keyname         NVARCHAR(30)      --(CS01)    
         , @n_TCartonNo       INT               --(CS01)    
         , @c_Facility        NVARCHAR(5)       --(CS01)    
         , @c_Child           NVARCHAR(10)      --(CS01)    
         , @c_CartonTo        NVARCHAR(10)      --(CS01)    
         , @c_CarrierName     NVARCHAR(30)      --(CS01)      
         , @c_DropID          NVARCHAR(20)      --(CS01)      
         , @c_TrackingNo_PI   NVARCHAR(50) =''  --(Wan01)    
         , @c_TrackingNo_PSR  NVARCHAR(30) =''  --NJOW01
      
         , @CUR_PACKSN        CURSOR      
         , @CUR_TrackingNo    CURSOR        --(CS01)    
         , @CUR_PD            CURSOR        --(CS01)     
         
         , @c_PackLabelToOrd  NVARCHAR(20)   --WL01
       
      
   SET @b_Success= 1       
   SET @n_Err    = 0        
   SET @c_ErrMsg = ''      
   SET @b_Debug  = 0       
   SET @n_Continue = 1        
   SET @n_StartTCnt = @@TRANCOUNT        
    
  --CS01 Start    
    
   SET @c_Orderkey = ''      
   SELECT @c_Orderkey = Orderkey       
   FROM PACKHEADER WITH (NOLOCK)      
   WHERE PickSlipNo = @c_PickSlipNo      
      
   IF @c_Orderkey = ''      
   BEGIN      
      GOTO SERIAL_UPDATE--QUIT_SP      
   END      
         
   SET @c_TrackingNo = ''      
   SELECT TOP 1       
          @c_TrackingNo = ISNULL(RTRIM(TrackingNo),'')      
         --,@c_CarrierName= ISNULL(RTRIM(CarrierName),'')      
         --,@c_KeyName    = ISNULL(RTRIM(KeyName),'')      
   FROM CARTONTRACK WITH (NOLOCK)      
   WHERE LabelNo = @c_Orderkey      
   AND   CarrierRef2 = 'GET'      
   ORDER BY AddDate      
      
   IF @c_TrackingNo = ''      
   BEGIN      
      GOTO SERIAL_UPDATE --QUIT_SP      
   END     
    
   SET @c_TotalCtn = 1    
   SET @c_TrackingNo = ''    
    
   SELECT @c_TotalCtn = MAX(Cartonno)    
   FROM PACKDETAIL WITH (NOLOCK)    
   WHERE Pickslipno = @c_PickSlipNo    
    
   IF @c_TotalCtn > 0    
   BEGIN    
     UPDATE PACKHEADER WITH (ROWLOCK)      
     SET TTLCNTS = @c_TotalCtn     
     WHERE PickSlipNo = @c_PickSlipNo      
   END    
      
   SET @n_Err = @@ERROR       
   IF @n_Err <> 0      
   BEGIN      
       SET @n_Continue = 3      
       SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)       
       SET @n_Err = 61801      
       SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKHEADER Fail. (ispPAKCF09)'      
                       + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'      
       GOTO QUIT_SP      
   END      
    
    
   SET @CUR_TrackingNo = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
   SELECT DISTINCT       
          PH.Orderkey      
      ,   OH.Shipperkey    
      ,   OH.Trackingno      
      ,   PD.CartonNo      
   FROM PACKHEADER PH  WITH (NOLOCK)      
   JOIN Orders OH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey)      
   JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno    
   WHERE PH.Pickslipno = @c_PickSlipNo      
      
   OPEN @CUR_TrackingNo        
        
   FETCH NEXT FROM @CUR_TrackingNo INTO @c_Orderkey      
                                     ,  @c_shipperkey     
                                     ,  @c_OHTrackingNo     
                                     ,  @n_TCartonNo      
      
   WHILE @@FETCH_STATUS <> -1      
   BEGIN     
      SET @c_keyname = ''    
      SET @c_Facility = ''    
      SET @c_TrackingNo = ''    
      SET @c_Child = '-' + RTRIM(CONVERT(NVARCHAR(10), @n_TCartonNo))    
      SET @c_CartonTo = '0'    
       
      SELECT @c_Facility = OH.Facility    
      FROM ORDERS OH WITH (NOLOCK)    
      WHERE OH.Orderkey = @c_Orderkey    
       
      SELECT @c_keyname = C.long    
      FROM CODELKUP C WITH (NOLOCK)    
      WHERE C.listname = 'AsgnTNo'    
      AND C.storerkey = @c_Storerkey    
      AND C.short = @c_shipperkey    
      AND C.notes = @c_Facility    
      AND C.UDF05 = ''   --WL01
       
      IF ISNULL(@c_OHTrackingNo,'') = ''    
      BEGIN    
         GOTO NEXT_CARTON    
      END    
      
      --WL01 S
      IF ISNULL(@c_keyname,'') = ''
      BEGIN
         GOTO NEXT_CARTON
      END
      --WL01 E
       
      IF @c_TotalCtn = 1    
      BEGIN    
        --SET @c_CartonTo = '-1-'    
       
        SET @c_TrackingNo = @c_OHTrackingNo +  @c_Child --+ @c_CartonTo    
      END    
      ELSE    
      BEGIN    
            
         IF @n_TCartonNo <> @c_TotalCtn    
         BEGIN    
           --SET @c_CartonTo = '-0-'    
          
           SET @c_TrackingNo = @c_OHTrackingNo +  @c_Child --+ @c_CartonTo    
          
         END    
         ELSE    
         BEGIN    
          
           --SET @c_CartonTo = '-' + RTRIM(CONVERT(NVARCHAR(10), @n_TCartonNo)) + '-'    
          
           SET @c_TrackingNo = @c_OHTrackingNo + @c_Child --+ @c_CartonTo    
          
         END    
      END    
    
      SET @CUR_PD =CURSOR FAST_FORWARD READ_ONLY FOR      
      SELECT PD.LabelLine      
         ,   DropID = ISNULL(RTRIM(PD.DropID),'')      
         ,   TrackingNo_PI = CASE WHEN ISNULL(PF.TrackingNo,'') <> '' THEN PF.TrackingNo ELSE '' END    --(Wan01)   
         --,   TrackingNo_PI = CASE WHEN ISNULL(PF.TrackingNo,'') <> '' THEN PF.TrackingNo ELSE ISNULL(PF.RefNo,'') END    --(Wan01)                                                                                                                                   
      FROM   PACKDETAIL PD WITH (NOLOCK)      
      JOIN PackInfo PF WITH (NOLOCK) ON PF.PickSlipNo=PD.PickSlipNo and PF.CartonNo=PD.CartonNo    
      WHERE  PD.PickSlipNo = @c_PickSlipNo      
      AND    PD.CartonNo = @n_TCartonNo      
      ORDER BY PD.LabelLine      
      
      OPEN @CUR_PD      
         
      FETCH NEXT FROM @CUR_PD INTO @c_LabelLine      
                                  ,@c_DropID         
                                  ,@c_TrackingNo_PI                     
      WHILE @@FETCH_STATUS <> -1      
      BEGIN      
      
         IF @c_DropID <> @c_TrackingNo                
         BEGIN                                                                 
            UPDATE PACKDETAIL WITH (ROWLOCK)      
            SET DropID = @c_TrackingNo    
              , LabelNo = @c_TrackingNo   --WL01
            WHERE PickSlipNo = @c_PickSlipNo      
            AND   CartonNo = @n_TCartonNo      
            AND   LabelLine= @c_LabelLine      
      
            SET @n_Err = @@ERROR       
            IF @n_Err <> 0      
            BEGIN      
               SET @n_Continue = 3      
               SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)       
               SET @n_Err = 61802      
               SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKDETIL Fail. (ispPAKCF09)'      
                             + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'      
               GOTO QUIT_SP      
            END      
         END        
       
         IF @c_TrackingNo_PI <> @c_TrackingNo                
         BEGIN                                                                 
            UPDATE PACKINFO WITH (ROWLOCK)      
            SET --refno = @c_TrackingNo 
               --,TrackingNo = @c_TrackingNo        --(Wan01)     
               TrackingNo = @c_TrackingNo           --(Wan01)   
            WHERE PickSlipNo = @c_PickSlipNo      
            AND   CartonNo = @n_TCartonNo      
     
            SET @n_Err = @@ERROR       
            IF @n_Err <> 0      
            BEGIN      
               SET @n_Continue = 3      
               SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)       
               SET @n_Err = 61803      
               SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKINFO Fail. (ispPAKCF09)'      
                             + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'      
               GOTO QUIT_SP      
            END      
         END           
         
         --NJOW01 S
         SET @c_TrackingNo_PSR = ''
         SELECT TOP 1 @c_TrackingNo_PSR = LabelNo
         FROM PACKSERIALNO (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo 
         AND CartonNo = @n_TCartonNo          
         
         IF @c_TrackingNo_PSR <> @c_TrackingNo
         BEGIN
            UPDATE PACKSERIALNO WITH (ROWLOCK)
            SET LabelNo = @c_TrackingNo,
                TrafficCop = NULL
            WHERE PickSlipNo = @c_PickSlipNo 
            AND CartonNo = @n_TCartonNo 
            AND LabelNo = @c_TrackingNo_PSR

            SET @n_Err = @@ERROR       
            IF @n_Err <> 0      
            BEGIN      
               SET @n_Continue = 3      
               SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)       
               SET @n_Err = 61804      
               SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKSERIALNO Fail. (ispPAKCF09)'      
                             + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'      
               GOTO QUIT_SP      
            END      
         END
         --NJOW01 E
               
         FETCH NEXT FROM @CUR_PD INTO @c_LabelLine      
                                    , @c_DropID     
                                    , @c_TrackingNo_PI                 
      END      
      CLOSE @CUR_PD      
      DEALLOCATE @CUR_PD      
    
    
      IF EXISTS ( SELECT 1    
                  FROM CartonTrack WITH (NOLOCK)    
                  WHERE TrackingNo = @c_TrackingNo    
                  AND LabelNo  = @c_Orderkey    
                  AND CarrierRef2 = 'GET'    
               )                                               
      BEGIN    
         GOTO NEXT_CARTON    
      END                                                     
    
      INSERT INTO CARTONTRACK     
            (  TrackingNo    
            ,  CarrierName    
            ,  KeyName    
            ,  LabelNo    
            ,  CarrierRef2    
            ,  UDF02    
            )    
      VALUES(      
               @c_TrackingNo    
            ,  @c_shipperkey    
            ,  @c_KeyName + '_Child'    
            ,  @c_Orderkey    
            ,  'GET'    
            ,  @c_TrackingNo    
            )    
       
    
      --SELECT  @c_TrackingNo '@c_TrackingNo',@c_shipperkey '@c_shipperkey',@c_KeyName + '_Child' as keyname,@c_Orderkey '@c_Orderkey'    
      SET @n_Err = @@ERROR     
      IF @n_Err <> 0    
      BEGIN    
         SET @n_Continue = 3    
         SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)     
         SET @n_Err = 61805    
         SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update CARTONTRACK Fail. (ispPAKCF09) '    
                       + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'    
         GOTO QUIT_SP    
      END    
    
      NEXT_CARTON:                                                --(CS01)      
    
      FETCH NEXT FROM @CUR_TrackingNo INTO @c_Orderkey      
                                        ,  @c_shipperkey    
                                        ,  @c_OHTrackingNo      
                                        ,  @n_TCartonNo    
   END      
   CLOSE @CUR_TrackingNo      
   DEALLOCATE @CUR_TrackingNo 

   --WL01 S
   EXEC nspGetRight 
      ''                   -- facility
   ,  @c_storerkey         -- Storerkey
   ,  null                 -- Sku
   ,  'AssignPackLabelToOrdCfg'       -- Configkey
   ,  @b_success           OUTPUT 
   ,  @c_PackLabelToOrd    OUTPUT 
   ,  @n_err               OUTPUT 
   ,  @c_errmsg            OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 61806 
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (ispPAKCF09)' 
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT_SP
   END 

   IF @c_PackLabelToOrd = '1'
   BEGIN
      EXEC isp_AssignPackLabelToOrderByLoad
            @c_PickSlipNo= @c_PickSlipNo
         ,  @b_Success   = @b_Success  OUTPUT
         ,  @n_Err       = @n_Err      OUTPUT
         ,  @c_ErrMsg    = @c_ErrMsg   OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61807
         SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                        + 'Error Executing isp_AssignPackLabelToOrderByLoad.(ispPAKCF09)'
         GOTO QUIT_SP
      END
   END
   --WL01 E

   --CS01 End    
   SERIAL_UPDATE:    
   SET @CUR_PACKSN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
   SELECT DISTINCT       
          PH.Orderkey      
      ,   PH.PackStatus      
      ,   PSN.CartonNo      
      ,   PSN.LabelLine      
      ,   PSN.SerialNo      
   FROM PACKHEADER PH  WITH (NOLOCK)      
   JOIN PACKSERIALNO PSN WITH (NOLOCK) ON (PH.PickSlipNo = PSN.Pickslipno)      
   WHERE PH.Pickslipno = @c_PickSlipNo      
      
   OPEN @CUR_PACKSN        
        
   FETCH NEXT FROM @CUR_PACKSN INTO @c_Orderkey      
                                 ,  @c_PackStatus      
                                 ,  @n_CartonNo      
                                 ,  @c_LabelLine      
                                 ,  @c_SerialNo      
      
   WHILE @@FETCH_STATUS <> -1      
   BEGIN       
      IF @c_PackStatus <> 'REPACK'      
      BEGIN      
         SET @c_SerialNoKey = ''      
         SELECT @c_SerialNoKey = SN.SerialNoKey      
         FROM SERIALNO SN WITH (NOLOCK)      
         WHERE SN.Storerkey = @c_Storerkey      
         AND   SN.SerialNo  = @c_SerialNo      
         AND   SN.Status < '6'      
      
       IF @c_SerialNoKey <> ''      
         BEGIN       
            UPDATE SERIALNO       
            SET Orderkey = @c_Orderkey      
               ,[Status]   = '6'            
               ,EditWho  = SUSER_NAME()        
               ,EditDate = GETDATE()      
            WHERE SerialNoKey = @c_SerialNoKey      
      
            SET @n_err = @@ERROR          
            IF @n_err <> 0          
            BEGIN          
               SET @n_continue = 3          
               SET @n_err = 61808-- Should Be Set To The SQL Errmessage but I don't know how to do so.       
               SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table SERIALNO. (ispPAKCF09)'         
      
               GOTO QUIT_SP       
            END       
         END      
      END      
      FETCH NEXT FROM @CUR_PACKSN INTO @c_Orderkey      
                                    ,  @c_PackStatus      
                                    ,  @n_CartonNo      
                                    ,  @c_LabelLine      
                                    ,  @c_SerialNo      
   END      
   CLOSE @CUR_PACKSN      
   DEALLOCATE @CUR_PACKSN      
      
   QUIT_SP:      
      
   IF @n_continue = 3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_success = 0      
      
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt      
      BEGIN      
         ROLLBACK TRAN      
      END      
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF09'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
   ELSE      
   BEGIN      
      SET @b_success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
        COMMIT TRAN      
      END       
      RETURN      
   END       
END


GO