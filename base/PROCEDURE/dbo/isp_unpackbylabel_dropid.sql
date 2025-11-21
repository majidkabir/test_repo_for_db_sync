SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_UnpackByLabel_DropID                                    */
/* Creation Date: 02-MAY-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1801 - CN&SG Logitech UnPack                            */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 02-JUL-2020 Wan01    1.1   WMS-13254 - [CN]Logitech_Tote ID          */
/*                            Packing_pallet serialno_CR                */
/************************************************************************/
CREATE PROC [dbo].[isp_UnpackByLabel_DropID] 
            @c_LabelNo        NVARCHAR(20)
         ,  @b_Success        INT = 0           OUTPUT 
         ,  @n_err            INT = 0           OUTPUT 
         ,  @c_errmsg         NVARCHAR(255) = ''OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT
         
         , @c_DropID             NVARCHAR(20)
         , @c_Orderkey           NVARCHAR(10)
         , @c_PackStatus         NVARCHAR(10)
         , @c_PickSlipNo         NVARCHAR(10) 
         , @n_CartonNo           INT
         , @c_LabelLine          NVARCHAR(5) 
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @n_Qty                INT
         , @n_QtyPicked          INT
         , @n_UnPickQty          INT
         , @n_RowNo              INT
         , @n_Exists             INT

         , @c_SerialNoKey        NVARCHAR(10) 
         , @c_PickDetailKey      NVARCHAR(10)  
         , @c_PickStatus         NVARCHAR(10)

         , @c_PICKDET_InsLog     NVARCHAR(30)
         , @c_UnallocUnPackSku   NVARCHAR(30)

         , @c_LogitechRules      NVARCHAR(30)

   --(Wan01) - START
   DECLARE @n_TrackingIDKey      BIGINT = 0                           
         , @c_ParentTrackingID   NVARCHAR(30)= '' 
         , @c_SerialNo           NVARCHAR(30)= ''       
         , @CUR_MInP             CURSOR            
   --(Wan01) - END

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   WHILE @@TRANCOUNT > 0 
   BEGIN 
      COMMIT TRAN
   END
    
   DECLARE CUR_UNPACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   RowNo = ROW_NUMBER() OVER ( ORDER BY PACKDETAIL.PickSlipNo, PACKDETAIL.CartonNo)
         ,  PACKDETAIL.PickSlipNo 
         ,  PACKDETAIL.CartonNo
         ,  PACKDETAIL.LabelLine
         ,  PACKDETAIL.Storerkey
         ,  PACKDETAIL.Sku
         ,  PACKDETAIL.Qty
         ,  PACKDETAIL.DropID
   FROM PACKDETAIL WITH (NOLOCK)
   WHERE PACKDETAIL.LabelNo = @c_LabelNo
   ORDER BY PACKDETAIL.PickSlipNo
         ,  PACKDETAIL.CartonNo
   
   OPEN CUR_UNPACK
   
   FETCH NEXT FROM CUR_UNPACK INTO @n_RowNo
                                 , @c_PickSlipNo
                                 , @n_CartonNo
                                 , @c_LabelLine
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @n_Qty
                                 , @c_DropID
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      BEGIN TRAN
      IF @n_RowNo = 1
      BEGIN
         SET @c_PackStatus = '0'
         SELECT @c_Orderkey = Orderkey
               ,@c_PackStatus   = Status
         FROM PACKHEADER WITH (NOLOCK) 
         WHERE PickSlipNo = @c_PickSlipNo

         SET @c_UnallocUnPackSku = ''

         EXEC nspGetRight      
               @c_Facility  = NULL      
            ,  @c_StorerKey = @c_StorerKey      
            ,  @c_sku       = NULL      
            ,  @c_ConfigKey = 'UnallocUnPackSku'      
            ,  @b_Success   = @b_Success           OUTPUT      
            ,  @c_authority = @c_UnallocUnPackSku  OUTPUT      
            ,  @n_err       = @n_err               OUTPUT      
            ,  @c_errmsg    = @c_errmsg            OUTPUT     

         SET @c_PICKDET_InsLog = ''

         EXEC nspGetRight      
               @c_Facility  = NULL      
            ,  @c_StorerKey = @c_StorerKey      
            ,  @c_sku       = NULL      
            ,  @c_ConfigKey = 'PICKDET_InsertLog'      
            ,  @b_Success   = @b_Success           OUTPUT      
            ,  @c_authority = @c_PICKDET_InsLog    OUTPUT      
            ,  @n_err       = @n_err               OUTPUT      
            ,  @c_errmsg    = @c_errmsg            OUTPUT  
            
         SET @c_LogitechRules = ''

         EXEC nspGetRight      
               @c_Facility  = NULL      
            ,  @c_StorerKey = @c_StorerKey      
            ,  @c_sku       = NULL      
            ,  @c_ConfigKey = 'LogitechRules'      
            ,  @b_Success   = @b_Success           OUTPUT      
            ,  @c_authority = @c_LogitechRules     OUTPUT      
            ,  @n_err       = @n_err               OUTPUT      
            ,  @c_errmsg    = @c_errmsg            OUTPUT                   

      END

      DECLARE CUR_UNSN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SerialNoKey
            ,SerialNo                                          --(Wan01)
      FROM SERIALNO WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      AND   CartonNo   = @n_CartonNo
      AND   LabelLine  = @c_LabelLine

      OPEN CUR_UNSN
   
      FETCH NEXT FROM CUR_UNSN INTO @c_SerialNoKey
                                 ,  @c_SerialNo                --(Wan01)
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_LogitechRules = '1'
         BEGIN
            UPDATE SERIALNO WITH (ROWLOCK)
            SET ExternStatus = 'CANC'
              , EditWho = SUSER_SNAME()
              , EditDate = GETDATE()
            WHERE SerialNoKey = @c_SerialNoKey

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3                                                                                              
               SET @n_err = 60010                                                                                              
               SET @c_errmsg='NSQL '+ CONVERT(CHAR(5),@n_err)+': Error UPDATE SERIALNO Table. (isp_UnpackByLabel_DropID)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                       
               GOTO QUIT_SP        
            END
            GOTO NEXT_SN
         END

         DELETE SERIALNO WITH (ROWLOCK)
         WHERE SerialNoKey = @c_SerialNoKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3                                                                                              
            SET @n_err = 60020                                                                                              
            SET @c_errmsg='NSQL '+ CONVERT(CHAR(5),@n_err)+': Error DELETE SERIALNO Table. (isp_UnpackByLabel_DropID)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                       
            GOTO QUIT_SP        
         END
         
         NEXT_SN:
         --(Wan01) - START
         SET @c_ParentTrackingID = ''  
         SELECT TOP 1 @c_ParentTrackingID = ParentTrackingID
         FROM TRACKINGID TID WITH (NOLOCK)
         WHERE TID.TrackingID= @c_SerialNo
         AND   TID.Storerkey = @c_Storerkey
         AND   TID.[Status]  = '9' 
         AND   TID.PickMethod<>'Loose'
         ORDER BY TrackingIDKey

         IF @c_ParentTrackingID <> ''
         BEGIN
            SET @CUR_MInP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TID.TrackingIDKey
            FROM TRACKINGID TID WITH (NOLOCK)
            WHERE TID.ParentTrackingID = @c_ParentTrackingID
            AND   TID.Storerkey = @c_Storerkey
            AND   TID.[Status]  = '9' 
            AND   TID.PickMethod<>'Loose'  
            ORDER BY TrackingIDKey

            OPEN @CUR_MInP

            FETCH NEXT FROM @CUR_MInP INTO @n_TrackingIDKey

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE TRACKINGID
                  SET PickMethod = 'Loose'
                     ,EditWho    = SUSER_SNAME()
                     ,EditDate   = GETDATE()
                     ,TrafficCop = NULL
               WHERE TrackingIDKey = @n_TrackingIDKey
               AND   Status  = '9'

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 60025
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update TRACKINGID Table. (isp_Insert_Packing_DropID)' 
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                  GOTO QUIT_SP
               END
               FETCH NEXT FROM @CUR_MInP INTO @n_TrackingIDKey
            END
            CLOSE @CUR_MInP
            DEALLOCATE @CUR_MInP
         END
         --(Wan01) - END

         FETCH NEXT FROM CUR_UNSN INTO @c_SerialNoKey
                                    ,  @c_SerialNo                 --(Wan01)
      END
      CLOSE CUR_UNSN
      DEALLOCATE CUR_UNSN

      IF @c_UnallocUnPackSku = '1'
      BEGIN
         DECLARE CUR_UNALLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey
               ,Qty  
               ,Status   
         FROM PICKDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
         AND   Storerkey= @c_Storerkey
         AND   Sku = @c_Sku
         AND   DropID = @c_DropID
         ORDER BY PickDetailKey

         OPEN CUR_UNALLOC
   
         FETCH NEXT FROM CUR_UNALLOC INTO @c_PickDetailKey
                                       ,  @n_QtyPicked
                                       ,  @c_PickStatus                                       
         WHILE @@FETCH_STATUS <> -1 AND @n_Qty > 0
         BEGIN
            IF @n_Qty < @n_QtyPicked
            BEGIN
               SET @n_UnPickQty = @n_Qty

               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET Qty = Qty - @n_UnPickQty
               WHERE PickDetailKey = @c_PickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3                                                                                              
                  SET @n_err = 60030                                                                                              
                  SET @c_errmsg='NSQL '+ CONVERT(CHAR(5),@n_err)+': Error UPDATE PICKDETAIL Table. (isp_UnpackByLabel_DropID)' 
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                       
                  GOTO QUIT_SP        
               END

               IF @c_PICKDET_InsLog = 1
               BEGIN
                  INSERT INTO PickDet_LOG
                    (
                        PickDetailKey     ,OrderKey    ,OrderLineNumber
                     ,  Storerkey         ,Sku         ,Lot
                     ,  Loc               ,ID          ,UOM
                     ,  Qty               ,STATUS      ,DropID
                     ,  PackKey           ,WaveKey     ,AddDate
                     ,  AddWho            ,PickSlipNo  ,TaskDetailKey
                     ,  CaseID
                    )
                  SELECT 
                        PickDetailKey     ,OrderKey      ,OrderLineNumber
                     ,  Storerkey         ,Sku           ,Lot
                     ,  Loc               ,ID            ,UOM
                     ,  @n_QtyPicked      ,@c_PickStatus ,DropID
                     ,  PackKey           ,WaveKey       ,AddDate
                     ,  AddWho            ,@c_PickSlipNo ,TaskDetailKey
                     ,  CaseID
                  FROM PICKDETAIL WITH (NOLOCK)
                  WHERE PickDetailKey = @c_PickDetailKey  
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_continue = 3                                                                                              
                     SET @n_err = 60040                                                                                              
                     SET @c_errmsg='NSQL '+ CONVERT(CHAR(5),@n_err)+': Error INSERT PickDet_LOG Table. (isp_UnpackByLabel_DropID)' 
                                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                       
                     GOTO QUIT_SP        
                  END                                                                  
               END
            END
            ELSE
            BEGIN
               DELETE PICKDETAIL WITH (ROWLOCK)
               WHERE PickDetailKey = @c_PickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3                                                                                              
                  SET @n_err = 60050                                                                                              
                  SET @c_errmsg='NSQL '+ CONVERT(CHAR(5),@n_err)+': Error DELETE PICKDETAIL Table. (isp_UnpackByLabel_DropID)' 
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                       
                  GOTO QUIT_SP        
               END

               SET @n_UnPickQty = @n_QtyPicked
            END

            SET @n_Qty = @n_Qty - @n_UnPickQty

            FETCH NEXT FROM CUR_UNALLOC INTO @c_PickDetailKey
                                          ,  @n_QtyPicked 
                                          ,  @c_PickStatus                                           
         END
         CLOSE CUR_UNALLOC
         DEALLOCATE CUR_UNALLOC
      END

      DELETE PACKDETAIL WITH (ROWLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      AND   CartonNo   = @n_CartonNo
      AND   LabelLine  = @c_LabelLine

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3                                                                                              
         SET @n_err = 60060                                                                                              
         SET @c_errmsg='NSQL '+ CONVERT(CHAR(5),@n_err)+': Error DELETE PACKDETAIL Table. (isp_UnpackByLabel_DropID)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                       
         GOTO QUIT_SP        
      END

      WHILE @@TRANCOUNT > 0
      BEGIN 
         COMMIT TRAN
      END 

      FETCH NEXT FROM CUR_UNPACK INTO @n_RowNo
                                    , @c_PickSlipNo
                                    , @n_CartonNo
                                    , @c_LabelLine
                                    , @c_Storerkey
                                    , @c_Sku
                                    , @n_Qty
                                    , @c_DropID
   END
   CLOSE CUR_UNPACK
   DEALLOCATE CUR_UNPACK    
   
   SET @n_Exists = 0
   IF @c_PackStatus = '9' AND @c_PickSlipNo <> '' AND @c_Orderkey <> ''
   BEGIN
      WITH 
      PICK_ORD( Orderkey, Storerkey, Sku, QtyAllocated)
      AS (  SELECT OD.Orderkey, OD.Storerkey, OD.Sku, QtyAllocated = ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)
            FROM ORDERDETAIL OD WITH (NOLOCK)
            WHERE OD.Orderkey = @c_Orderkey
            GROUP BY OD.Orderkey, OD.Storerkey, OD.Sku
         )
      ,
      PACK_ORD( Orderkey, Storerkey, Sku, QtyPacked)
      AS (  SELECT @c_Orderkey, PD.Storerkey, PD.Sku, QtyPacked = ISNULL(SUM(PD.Qty),0)
            FROM PACKDETAIL PD WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            GROUP BY PD.Storerkey, PD.Sku
         )

 
      SELECT @n_Exists = 1 
      FROM PICK_ORD
      LEFT JOIN PACK_ORD ON  (PICK_ORD.Orderkey = PACK_ORD.Orderkey)
                         AND (PICK_ORD.Storerkey= PACK_ORD.Storerkey) 
                         AND (PICK_ORD.Sku      = PACK_ORD.Sku)                         
      WHERE PICK_ORD.QtyAllocated > ISNULL(PACK_ORD.QtyPacked,0)

      IF @n_Exists = 1
      BEGIN
         BEGIN TRAN
         EXEC  isp_UnpackReversal
               @c_PickSlipNo  = @c_PickSlipNo
            ,  @c_UnpackType  = 'R'
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT

         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3                                                                                              
            SET @n_err = 60070                                                                                              
            SET @c_errmsg='NSQL '+ CONVERT(CHAR(5),@n_err)+': Error Executing isp_UnpackReversal. (isp_UnpackByLabel_DropID)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                       
            GOTO QUIT_SP        
         END

         WHILE @@TRANCOUNT > 0
         BEGIN 
            COMMIT TRAN
         END 
      END
   END        
   
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT > 0 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_UnpackByLabel_DropID'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN 
      BEGIN TRAN
   END 
END -- procedure

GO