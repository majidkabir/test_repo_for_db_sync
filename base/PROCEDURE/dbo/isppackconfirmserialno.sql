SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPackConfirmSerialNo                                      */
/* Creation Date: 26-APR-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-1816 - CN_DYSON_Exceed_ECOM PACKING                     */
/*        :                                                             */
/* Called By:  isp_Ecom_PackConfirm                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2019-03-14  Ung      1.1   WMS-8134 Add SKU.SerialNoCapture = 3      */
/* 2019-08-29  NJOW01   1.2   Fix-Skip checking for PackSerialNoCapture */
/* 2020-02-27  WLChooi  1.3   WMS-10615 - Add PACKNoCheckSerialNoCapture*/
/*                            to skip check on PackSerialNo table (WL01)*/
/************************************************************************/
CREATE PROC [dbo].[ispPackConfirmSerialNo] 
            @c_PickSlipNo  NVARCHAR(10)               
         ,  @b_Success     INT = 0           OUTPUT 
         ,  @n_err         INT = 0           OUTPUT 
         ,  @c_errmsg      NVARCHAR(255) = ''OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                   INT
         , @n_Continue                    INT    
                                          
         , @n_CartonNo                    INT
         , @c_Storerkey                   NVARCHAR(15)
         , @c_Facility                    NVARCHAR(5)
         , @c_Orderkey                    NVARCHAR(10)
         , @c_Loadkey                     NVARCHAR(10)  
         , @c_PackStatus                  NVARCHAR(10)  
         , @c_PACKNoCheckSerialNoCapture  NVARCHAR(1)   --WL01
            
   DECLARE @c_LabelNo NVARCHAR( 20), @c_LabelLine NVARCHAR(5), @n_QTY INT
   DECLARE @c_SerialNoKey NVARCHAR( 10), @c_SKU NVARCHAR(20), @c_SerialNo NVARCHAR(30), @n_SerialQTY INT, @c_Status NVARCHAR( 10)
   DECLARE @c_PackSerialNoCapture NVARCHAR(30) --NJOW01

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1
                
   IF NOT EXISTS( SELECT TOP 1 1 
      FROM PackDetail PD WITH (NOLOCK) 
         JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE PD.PickSlipNo = @c_PickSlipNo
         AND SKU.SerialNoCapture IN ('1', '3')) -- 1=Inbound and outbound, 3=Outbound only
   BEGIN   	   	
      GOTO QUIT_SP
   END 
   
   --NJOW01 S
   SELECT @c_Storerkey = O.Storerkey, 
          @c_Facility = O.Facility
   FROM PACKHEADER PH (NOLOCK) 
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   WHERE PH.Pickslipno = @c_Pickslipno
   
   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                   @c_Facility = O.Facility
      FROM PACKHEADER PH (NOLOCK)
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.Loadkey = LPD.Loadkey 
      JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
      WHERE PH.Pickslipno = @c_Pickslipno   	    	 
   END
   
   SELECT @c_PACKNoCheckSerialNoCapture = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PACKNoCheckSerialNoCapture')   --WL01
   SELECT @c_PackSerialNoCapture = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PackSerialNoCapture') 
   
   IF @c_PackSerialNoCapture = '1' OR @c_PACKNoCheckSerialNoCapture = '1' --WL01
   BEGIN
   	  IF NOT EXISTS(SELECT 1
                    FROM PackSerialNo WITH (NOLOCK) 
                    WHERE PickSlipNo = @c_PickSlipNo)
      BEGIN
      	 GOTO QUIT_SP --if turn on PackSerialNoCapture and no PackSerialNo records not to proceed PackSerialNo table update.
      END              
   END
   --NJOW01 E
   
   -- Check PackDetail tally with PackSerialNo
   DECLARE @curPD CURSOR
   SET @curPD = CURSOR FAST_FORWARD READ_ONLY FOR      
      SELECT PD.CartonNo, PD.LabelNo, PD.LabelLine, PD.QTY
      FROM PackDetail PD WITH (NOLOCK) 
         JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE PD.PickSlipNo = @c_PickSlipNo
         AND SKU.SerialNoCapture IN ('1', '3') -- 1=Inbound and outbound, 3=Outbound only
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @n_CartonNo, @c_LabelNo, @c_LabelLine, @n_QTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      DECLARE @nSerialQTY INT
      SELECT @nSerialQTY = ISNULL( SUM( QTY), 0)
      FROM PackSerialNo WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
         AND CartonNo = @n_CartonNo
         AND LabelNo = @c_LabelNo
         AND LabelLine = @c_LabelLine
                     
      -- Check QTY tally
      IF @nSerialQTY <> @n_QTY
      BEGIN
         SELECT @n_continue = 3                
         SELECT @n_err = 111101
         SELECT @c_errmsg = 'NSQL' + CAST( @n_err AS NVARCHAR(6)) 
                           + ' Serial no QTY not tally (between PackDetail and PackSerialNo table.'
                           + ' PickSlipNo=' + @c_PickSlipNo
                           + ' CartonNo=' + CAST( @n_CartonNo AS NVARCHAR( 5))
                           + ' LabelNo=' + @c_LabelNo
                           + ' LabelLine=' + @c_LabelLine + ')'
                           + ' (ispPackConfirmSerialNo) '
          GOTO QUIT_SP
      END
                     
      FETCH NEXT FROM @curPD INTO @n_CartonNo, @c_LabelNo, @c_LabelLine, @n_QTY
   END

   SET @c_PackStatus = ''
   SELECT @c_PackStatus = ISNULL(PackStatus,'')
   FROM PACKHEADER WITH (NOLOCK) 
   WHERE PickSlipNo = @c_PickSlipNo

   -- Insert/update SerialNo
   SET @curPD = CURSOR FAST_FORWARD READ_ONLY FOR      
      SELECT CartonNo, Storerkey, SKU, SerialNo, QTY
      FROM PackSerialNo WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @n_CartonNo, @c_Storerkey, @c_SKU, @c_SerialNo, @n_SerialQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get SerialNo info
      SET @c_SerialNoKey = ''
      SET @c_Status = ''
      SELECT 
         @c_SerialNoKey = SerialNoKey, 
         @c_Status = Status
      FROM dbo.SerialNo (NOLOCK)
      WHERE SerialNo = @c_SerialNo
         AND StorerKey = @c_StorerKey
         AND SKU = @c_SKU

      IF @c_SerialNoKey <> ''
      BEGIN
         -- Not received and not repack
         IF (@c_Status <> '1') AND (@c_Status = '6' AND @c_PackStatus <> 'REPACK') 
         BEGIN
            SET @n_continue = 3
            IF @c_Status = '0'
               SELECT @n_err = 111102, @c_errmsg = 'NSQL109684: SerialNo not yet received.'
            ELSE IF @c_Status = '5'
               SELECT @n_err = 111103, @c_errmsg = 'NSQL109685: SerialNo already picked.'
            ELSE IF @c_Status = '6'
               SELECT @n_err = 111104, @c_errmsg = 'NSQL109686: SerialNo already packed.'
            ELSE IF @c_Status = '9'
               SELECT @n_err = 111105, @c_errmsg = 'NSQL109687: SerialNo shipped.'
            ELSE 
               SELECT @n_err = 111106, @c_errmsg = 'NSQL109688: SerialNo status unknown.'
            SET @c_errmsg = @c_errmsg + 
                           + ' PickSlipNo=' + @c_PickSlipNo
                           + ' CartonNo=' + CAST( @n_CartonNo AS NVARCHAR(5))
                           + ' SKU=' + @c_SKU
                           + ' SerialNo=' + @c_SerialNo
                           + ' Status=' + @c_Status
                           + ' (ispPackConfirmSerialNo)'                          
            GOTO QUIT_SP
         END

         -- Update SerialNo status
         UPDATE dbo.SerialNo WITH (ROWLOCK) SET
            Status = '6', -- 6=Pack
            EditDate = GETDATE(),  
            EditWho = SUSER_SNAME()
         WHERE SerialNoKey = @c_SerialNoKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 111107
            SET @c_errmsg = 'NSQL109680: Update SerialNo table fail (ispPackConfirmSerialNo)'
            GOTO QUIT_SP
         END

      END
      ELSE
      BEGIN
         -- Get SerialNoKey
         EXECUTE nspg_getkey
               'SerialNo'
            ,10
            ,@c_SerialNoKey OUTPUT
            ,@b_Success     OUTPUT
            ,@n_Err         OUTPUT
            ,@c_ErrMsg      OUTPUT
         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 111108
            SET @c_errmsg = 'NSQL94213: GetKey fail. (ispPackConfirmSerialNo)'
            GOTO QUIT_SP
         END
                           
         -- Insert SerialNo
         INSERT INTO dbo.SerialNo (SerialNoKey, StorerKey, SKU, SerialNo, QTY, Status, OrderKey, OrderLineNumber)
         VALUES (@c_SerialNoKey, @c_StorerKey, @c_SKU, @c_SerialNo, @n_SerialQTY, '6', '', '')
         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 111109
            SET @c_errmsg = 'NSQL94214: Insert SerialNo table fail (ispPackConfirmSerialNo)'
            GOTO QUIT_SP
         END
      END

      FETCH NEXT FROM @curPD INTO @n_CartonNo, @c_Storerkey, @c_SKU, @c_SerialNo, @n_SerialQTY
   END
   
   IF EXISTS( SELECT TOP 1 1 FROM PackSerialNo WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
   BEGIN
      SET @c_Storerkey = ''
      SET @c_Orderkey  = ''
      SET @c_Loadkey   = ''

      SELECT @c_Storerkey = PH.Storerkey
            ,@c_Orderkey  = PH.Orderkey
            ,@c_Loadkey   = PH.Loadkey
      FROM PACKHEADER  PH WITH (NOLOCK)
      LEFT JOIN ORDERS OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
      WHERE PickSlipNo = @c_PickSlipNo

      SET @b_Success = 0
      EXECUTE dbo.ispUpdatePackSerialNoWrapper   
           @c_Storerkey  = @c_Storerkey
         , @c_Facility   = @c_Facility 
         , @c_PickSlipNo = @c_PickSlipNo
         , @c_OrderKey   = @c_OrderKey   
         , @c_loadKey    = @c_loadKey  
         , @b_Success    = @b_Success     OUTPUT    
         , @n_Err        = @n_err         OUTPUT     
         , @c_ErrMsg     = @c_errmsg      OUTPUT    
         , @b_debug      = 0   
                  
      IF @n_err <> 0    
         SET @n_continue = 3
   END

   QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0      
      DECLARE @n_IsRDT INT      
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT      
      
      IF @n_IsRDT = 1      
      BEGIN      
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here      
         -- Instead we commit and raise an error back to parent, let the parent decide      
      
         -- Commit until the level we begin with      
         WHILE @@TRANCOUNT > @n_StartTCnt      
            COMMIT TRAN      
      
         -- Raise error with severity = 10, instead of the default severity 16.      
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger      
         -- RAISERROR (@n_err, 10, 1) WITH SETERROR      
      
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten      
      END      
      ELSE      
      BEGIN            
         IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
   
         EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPackConfirmSerialNo'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      END
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END

GO