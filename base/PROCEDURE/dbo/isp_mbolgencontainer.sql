SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_MBOLGenContainer                               */  
/* Creation Date: 10-SEP-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#255609 - QS MBOL Generate Container                     */  
/*                                                                      */  
/* Called By: MBOL Ue_statue_rule                                       */
/*            (Storerconfig MBOLGenContainer)                           */ 
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_MBOLGenContainer]
      @c_MBOLKey  NVARCHAR(10)
   ,  @b_Success  INT             OUTPUT   -- @nSuccess = 0 (Fail), @nSuccess = 1 (Success), @nSuccess = 2 (Warning)
   ,  @n_Err      INT             OUTPUT 
   ,  @c_ErrMsg   NVARCHAR(250)   OUTPUT
AS 
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue     INT
         , @n_StartTCnt    INT

         , @n_CNTRLineNo   INT
         , @n_PLTLineNo    INT
         , @c_Facility     NVARCHAR(5) 
         , @c_ContainerKey NVARCHAR(10)
         , @c_CNTRLineNo   NVARCHAR(5)
         , @c_Palletkey    NVARCHAR(10)
         , @c_PLTLineNo    NVARCHAR(5)
         , @c_Storerkey    NVARCHAR(15)
         , @c_Orderkey     NVARCHAR(10)
         , @c_Sku          NVARCHAR(20)
         , @c_LabelNo      NVARCHAR(20)
         , @c_Loc          NVARCHAR(10)
         , @n_Qty          INT

         , @c_OrderkeyPrev NVARCHAR(10)

   SET @n_Err           = 0
   SET @b_Success       = 1
   SET @c_ErrMsg        = ''

   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT

   SET @n_CNTRLineNo    = 0
   SET @n_PLTLineNo     = 0
   SET @c_Facility      = ''
   SET @c_ContainerKey  = ''
   SET @c_CNTRLineNo    = ''
   SET @c_Palletkey     = ''
   SET @c_PLTLineNo     = ''
   SET @c_Storerkey     = ''
   SET @c_Orderkey      = ''
   SET @c_Sku           = ''
   SET @c_LabelNo       = ''
   SET @c_Loc           = ''
   SET @n_Qty           = 0

   SEt @c_OrderkeyPrev  = ''

   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END

   IF EXISTS (SELECT 1 
              FROM CONTAINER CTNR WITH (NOLOCK)
              WHERE CTNR.MBOLKey = @c_MBOLKey)
   BEGIN
      GOTO QUIT_SP
   END 

   SELECT @c_Facility = MBOL.Facility
   FROM MBOL WITH (NOLOCK)
   WHERE MBOLKey = @c_MBOLKey




   -- Generate containerkey

   BEGIN TRAN

   EXECUTE nspg_GetKey
    'ContainerKey'
   ,10 
   ,@c_ContainerKey  OUTPUT 
   ,@b_success       OUTPUT 
   ,@n_err           OUTPUT 
   ,@c_errmsg        OUTPUT

   IF NOT @b_success = 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 30101
      SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Error Getting New ContainerKey. (isp_MBOLGenContainer)' 
      GOTO QUIT_SP
   END   
   
   INSERT INTO CONTAINER (ContainerKey, MBOLKey, OtherReference, Seal03, BookingReference, Status)
   VALUES (@c_ContainerKey, @c_MBOLKey, @c_MBOLKey, @c_Facility, 'UNKNOWN','0')

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 30102
      SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Error Insert Into CONTAINER. (isp_MBOLGenContainer)' 
      GOTO QUIT_SP
   END

   DECLARE CursorMBOLDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT MBD.OrderKey 
         ,ISNULL(RTRIM(PD.LabelNo),'')
         ,ISNULL(RTRIM(PD.Storerkey),'')
         ,ISNULL(RTRIM(PD.Sku),'')
         ,ISNULL(SUM(PD.Qty),0)
   FROM MBOLDETAIL MBD WITH (NOLOCK)
   JOIN PACKHEADER PH  WITH (NOLOCK) ON (MBD.Orderkey = PH.Orderkey)
   JOIN PACKDETAIL PD  WITH (NOLOCK) ON (PH.PickSlipNo= PD.PickSlipNo)
   WHERE MBOLKey = @c_MBOLKey
   GROUP BY MBD.OrderKey 
         ,  ISNULL(RTRIM(PD.LabelNo),'')
         ,  ISNULL(RTRIM(PD.Storerkey),'')
         ,  ISNULL(RTRIM(PD.Sku),'')
   ORDER BY MBD.OrderKey 

   OPEN CursorMBOLDetail   

   FETCH NEXT FROM CursorMBOLDetail INTO @c_OrderKey
                                       , @c_LabelNo
                                       , @c_Storerkey
                                       , @c_Sku
                                       , @n_Qty

   WHILE @@FETCH_STATUS <> -1               
   BEGIN
      SELECT @c_Loc = ISNULL(RTRIM(SVALUE),'')
      FROM RDT.Storerconfig WITH (NOLOCK)
      WHERE Function_id = '1638' 
      AND   Storerkey = @c_Storerkey 
      AND   Configkey   = 'DefaultToLOC'

      IF @c_Loc = '' 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 30104
         SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Default To Loc is required. (isp_MBOLGenContainer)' 
         GOTO QUIT_SP
      END

      IF @c_Orderkey <> @c_OrderkeyPrev
      BEGIN
         -- Generate Palletkey
         EXECUTE nspg_GetKey
          'PalletKey'
         ,10 
         ,@c_PalletKey  OUTPUT 
         ,@b_success    OUTPUT 
         ,@n_err        OUTPUT 
         ,@c_errmsg     OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 30105
            SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Error Getting New PalletKey. (isp_MBOLGenContainer)' 
            GOTO QUIT_SP
         END  

         SET @n_CNTRLineNo = @n_CNTRLineNo + 1
         SET @c_CNTRLineNo = RIGHT('00000' + CONVERT(VARCHAR(5), @n_CNTRLineNo), 5)
    
         INSERT INTO CONTAINERDETAIL ( ContainerKey, ContainerLineNumber, PalletKey )
         VALUES (@c_ContainerKey, @c_CNTRLineNo, @c_Palletkey)

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 30106
            SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Error Insert Into CONTAINERDETAIL. (isp_MBOLGenContainer)' 
            GOTO QUIT_SP
         END

         INSERT INTO PALLET( Storerkey, PalletKey, Status )
         VALUES (@c_Storerkey, @c_PalletKey, '0')

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 30107
            SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Error Insert Into PALLET. (isp_MBOLGenContainer)' 
            GOTO QUIT_SP
         END

         SET @n_PLTLineNo = 0
      END

      SET @n_PLTLineNo = @n_PLTLineNo + 1
      SET @c_PLTLineNo = RIGHT('00000' + CONVERT(VARCHAR(5), @n_PLTLineNo), 5)

      INSERT INTO PalletDetail ( PalletKey, PalletLineNumber, Caseid, Storerkey, Sku, Loc, Qty, Status )
      VALUES (@c_PalletKey, @c_PLTLineNo, @c_LabelNo, @c_Storerkey, @c_Sku, @c_Loc, @n_Qty, '0')

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 30108
         SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Error Insert Into PALLETDETAIL. (isp_MBOLGenContainer)' 
         GOTO QUIT_SP
      END

      SET @c_OrderkeyPrev = @c_Orderkey
      FETCH NEXT FROM CursorMBOLDetail INTO @c_OrderKey
                                          , @c_LabelNo
                                          , @c_Storerkey
                                          , @c_Sku
                                          , @n_Qty
   END 
   QUIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CursorMBOLDetail') in (0 , 1)
   BEGIN
      CLOSE CursorMBOLDetail
      DEALLOCATE CursorMBOLDetail
   END                       


   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_MBOLGenContainer'
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