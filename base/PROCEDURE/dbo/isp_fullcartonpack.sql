SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_FullCartonPack                                      */
/* Creation Date: 08-MAR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-4005 - SG - Triple - UCCDROPID packing module          */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_FullCartonPack]
           @c_PickSlipNo      NVARCHAR(10)
         , @n_CartonNo        INT            OUTPUT
         , @c_labelNo         NVARCHAR(20)
         , @c_DropID          NVARCHAR(20)
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Orderkey        NVARCHAR(10)
         , @c_Loadkey         NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)

         , @c_LabelLine       NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @n_QtyToPack       INT
         , @n_SumQtyAllocated INT
         , @n_SumQtyPacked    INT

         , @n_LineNo          INT
  
         , @c_checkPickB4Pack NVARCHAR(10)

         , @c_SQL             NVARCHAR(MAX)
         , @c_SQLParms        NVARCHAR(MAX)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF EXISTS (SELECT 1
               FROM PACKDETAIL PD WITH (NOLOCK)
               WHERE PD.PickSlipNo = @c_PickSlipNo
               AND DropId = @c_dropid
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err     = 60010
      SET @c_ErrMsg  = CONVERT(CHAR(5),@n_Err) + '. Carton #: ' + RTRIM(@c_DropID)
                     + ' had been packed. (isp_FullCartonPack)'
      GOTO QUIT_SP      
   END

   SET @n_LineNo   = 0

   SET @c_Orderkey = ''
   SET @c_Loadkey  = ''
   SET @c_Storerkey= ''
   SELECT @c_Orderkey = Orderkey 
      ,   @c_Loadkey = Loadkey
      ,   @c_Storerkey = Storerkey
   FROM PACKHEADER WITH(NOLOCK)
   WHERE PickSLipNo = @c_PickSlipNo

   SET @c_Facility = ''
   IF @c_Orderkey = ''
   BEGIN
      SELECT TOP 1 @c_Facility = Facility
      FROM LOADPLAN WITH (NOLOCK)
      WHERE Loadkey = Loadkey
   END
   ELSE
   BEGIN
      SELECT TOP 1 @c_Facility = Facility
      FROM ORDERS WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey
   END   

   SET @b_Success = 1
   EXEC nspGetRight  
         @c_Facility           
      ,  @c_StorerKey             
      ,  ''       
      ,  'CheckPickB4Pack'             
      ,  @b_Success           OUTPUT   
      ,  @c_CheckPickB4Pack   OUTPUT  
      ,  @n_err               OUTPUT  
      ,  @c_errmsg            OUTPUT


   IF @b_Success <> 1 
   BEGIN 
      SET @n_Continue = 3
      SET @n_Err     = 60020
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_Err) + '. Error Executing nspGetRight. (isp_FullCartonPack)'
      GOTO QUIT_SP
   END

   SET @n_CartonNo = 0
   SET @c_SQL = N'DECLARE CUR_CTN CURSOR FAST_FORWARD READ_ONLY FOR'
              + ' SELECT PD.Storerkey' 
              + ',PD.Sku'
              + ' ,Qty = SUM(PD.Qty)'
              + ' FROM ORDERS     OH WITH (NOLOCK)'
              + ' JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)'
              + ' WHERE PD.DropID = @c_DropID'
              + CASE WHEN @c_Orderkey = '' THEN ' AND OH.Loadkey = @c_Loadkey'
                                           ELSE ' AND OH.Orderkey= @c_Orderkey'
                                           END
              + CASE WHEN @c_checkPickB4Pack = '1' THEN ' AND PD.Status = ''5'''
                                                   ELSE ' AND PD.Status < ''5'''
                                                   END
              + ' GROUP BY PD.Storerkey, PD.SKU'

   SET @c_SQLParms = N'@c_DropID    NVARCHAR(20)'
                   + ',@c_Loadkey   NVARCHAR(10)'
                   + ',@c_Orderkey  NVARCHAR(10)'
        

   EXEC sp_executesql @c_SQL
         ,  @c_SQLParms
         ,  @c_DropID 
         ,  @c_Loadkey
         ,  @c_Orderkey         

  
   OPEN CUR_CTN
   
   FETCH NEXT FROM CUR_CTN INTO @c_Storerkey, @c_Sku, @n_QtyToPack 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_SumQtyAllocated = 0
      SET @c_SQL = N'SELECT @n_SumQtyAllocated = SUM(OD.QtyAllocated + OD.QtyPicked)' 

                 + ' FROM ORDERS      OH WITH (NOLOCK)'
                 + ' JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)'
                 + ' WHERE OD.Storerkey = @c_Storerkey'
                 + ' AND OD.Sku = @c_Sku'
                 + CASE WHEN @c_Orderkey = '' THEN ' AND OH.Loadkey = @c_Loadkey'
                                              ELSE ' AND OH.Orderkey= @c_Orderkey'
                                              END
      SET @c_SQLParms = N'@c_Storerkey       NVARCHAR(15)'
                      + ',@c_Sku             NVARCHAR(20)'
                      + ',@c_Loadkey         NVARCHAR(10)'
                      + ',@c_Orderkey        NVARCHAR(10)'
                      + ',@n_SumQtyAllocated INT OUTPUT'

      EXEC sp_executesql @c_SQL
            ,  @c_SQLParms
            ,  @c_Storerkey
            ,  @c_Sku 
            ,  @c_Loadkey
            ,  @c_Orderkey  
            ,  @n_SumQtyAllocated OUTPUT
 
      SET @n_SumQtyPacked = 0
      SELECT @n_SumQtyPacked = SUM(Qty)
      FROM PACKDETAIL PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @c_PickSlipNo
      AND PD.Storerkey = @c_Storerkey
      AND PD.Sku = @c_Sku

      IF @n_SumQtyAllocated - @n_SumQtyPacked < @n_QtyToPack
      BEGIN
         SET @n_Continue = 3
         SET @n_Err     = 60010
         SET @c_ErrMsg  = CONVERT(CHAR(5),@n_Err) + '. QtyPacked > Qty Remain to pack. (isp_FullCartonPack)'
         GOTO QUIT_SP  
      END

      --SET @n_LineNo = @n_LineNo + 1
      SET @c_LabelLine = ''
      IF @n_CartonNo > 0 
      BEGIN
         SELECT @n_LineNo = CONVERT(INT, ISNULL(MAX(LabelLine),0)) + 1
         FROM PACKDETAIL WITH (NOLOCK) 
         WHERE PickSlipNo= @c_PickSlipNo 

         set @c_LabelLine= RIGHT('00000' + CONVERT(NVARCHAR(5), @n_LineNo),5)
      END

      INSERT INTO PACKDETAIL     
            (  PickSlipNo  
            ,  CartonNo
            ,  LabelNo
            ,  LabelLine
            ,  Storerkey
            ,  Sku      
            ,  Qty
            ,  DropID
            )
      VALUES ( 
               @c_PickSlipNo  
            ,  @n_CartonNo
            ,  @c_LabelNo
            ,  @c_LabelLine
            ,  @c_Storerkey
            ,  @c_Sku      
            ,  @n_QtyToPack
            ,  @c_DropID
            ) 

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60030  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into PACKDETAIL Table. (isp_FullCartonPack)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END

      IF @n_CartonNo = 0 
      BEGIN
         SELECT @n_CartonNo = CartonNo
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE PickSlipNo= @c_PickSlipNo 
         AND   DropID = @c_DropID
      END

      FETCH NEXT FROM CUR_CTN INTO @c_Storerkey, @c_Sku, @n_QtyToPack  
   END
   CLOSE CUR_CTN
   DEALLOCATE CUR_CTN

QUIT_SP:
   IF CURSOR_STATUS( 'GLOBAL', 'CUR_CTN') in (0 , 1)  
   BEGIN
      CLOSE CUR_CTN
      DEALLOCATE CUR_CTN
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_FullCartonPack'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO