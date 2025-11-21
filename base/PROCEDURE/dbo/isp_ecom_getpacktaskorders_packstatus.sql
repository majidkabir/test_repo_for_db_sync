SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: isp_Ecom_GetPackTaskOrders_PackStatus                            */
/* Creation Date: 18-Oct-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20953 - MY - Add screen to view pending order           */
/*        :                                                             */
/* Called By: ECOM Packing - Single Order                               */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 18-Oct-2022 WLChooi  1.0   DevOps Combine Script                     */  
/* 20-JUL-2021 Wan01    1.1   WMS-23156 - [CN] GBMAX_Ecompack_Show Cancel*/
/*                            qty_CR                                    */
/************************************************************************/
CREATE   PROC [dbo].[isp_Ecom_GetPackTaskOrders_PackStatus] 
         @c_TaskBatchNo NVARCHAR(10)
      ,  @c_PickSlipNo  NVARCHAR(10)  = ''  
      ,  @c_Orderkey    NVARCHAR(10)  = ''  
      ,  @c_Type        NVARCHAR(10) = 'PENDING'
AS         
BEGIN 
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Cnt                   INT   = 0
         , @n_StartTCnt             INT
         , @c_SQL                   NVARCHAR(MAX)
         , @c_ExecArguments         NVARCHAR(MAX)
         , @c_SQLCondition          NVARCHAR(MAX)
         
         , @c_Facility              NVARCHAR(5) = ''                                --(Wan01)
         , @c_Storerkey             NVARCHAR(15)= ''                                --(Wan01)
         , @c_DetailAddTypes        NVARCHAR(60)= ''                                --(Wan01)
         , @c_EpackDetailAddTypeS   NVARCHAR(10)= '0'                               --(Wan01)

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   IF RTRIM(@c_TaskBatchNo) = '' OR @c_TaskBatchNo IS NULL
   BEGIN
      SELECT NULL, NULL, NULL, NULL, NULL, NULL
      GOTO QUIT_SP
   END

   SELECT TOP 1 @n_Cnt = 1                                                          --(Wan01) - START
         ,@c_Facility = o.Facility
         ,@c_Storerkey= o.StorerKey
   FROM PACKTASKDETAIL p WITH (NOLOCK)
   JOIN dbo.ORDERS AS o (NOLOCK) ON o.OrderKey = p.Orderkey
   WHERE p.TaskBatchNo = @c_TaskBatchNo
   ORDER BY p.ADDDate, p.RowRef 

   IF @n_Cnt > 0
   BEGIN
      SELECT @c_EpackDetailAddTypeS = fsgr.Authority                                
          ,  @c_DetailAddTypes = fsgr.ConfigOption1
      FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'EpackDetailAddTypeS') AS fsgr

      IF @c_EpackDetailAddTypeS = '1' AND @c_EpackDetailAddTypeS <> ''
      BEGIN
         IF CHARINDEX('ALL',@c_DetailAddTypes,1) > 0 
         BEGIN
            SET @c_Type = 'ALL'
         END
         ELSE IF CHARINDEX('PACKED',@c_DetailAddTypes,1) > 0 AND CHARINDEX('CANC',@c_DetailAddTypes,1) > 0
         BEGIN
            SET @c_Type = 'ALL'
         END   
         ELSE IF CHARINDEX('CANC',@c_DetailAddTypes,1) > 0
         BEGIN
            SET @c_Type = @c_DetailAddTypes
            SET @c_SQLCondition = ' AND PTD.[Status] NOT IN ( ''9'') '                
         END   
         ELSE IF CHARINDEX('PACKED',@c_DetailAddTypes,1) > 0
         BEGIN
            SET @c_Type = @c_DetailAddTypes
            SET @c_SQLCondition = ' AND PTD.[Status] <= ''9'' '                
         END            
      END                                                                           --(Wan01) - END      
  
      IF @c_Type = 'ALL'
      BEGIN
         SET @c_SQLCondition = ''
      END
      ELSE IF @c_Type = 'PACKED'
      BEGIN
         --SET @c_SQLCondition = ' AND ISNULL(PD.QtyPacked,0) = PTD.QtyAllocated'
         SET @c_SQLCondition = ' AND PTD.[Status] = ''9'' '
      END
      ELSE IF @c_Type = 'PENDING'
      BEGIN
         --SET @c_SQLCondition = ' AND ISNULL(PD.QtyPacked,0) < PTD.QtyAllocated'
         SET @c_SQLCondition = ' AND PTD.[Status] < ''9'' '                 
      END

      SET @c_SQL = N' SELECT PTD.TaskBatchNo ' + CHAR(13)
                 + N'      , OH.Orderkey ' + CHAR(13)
                 + N'      , OH.LoadKey ' + CHAR(13)
                 + N'      , PTD.Sku ' + CHAR(13)
                 + N'      , PTD.QtyAllocated ' + CHAR(13)
                 + N'      , ISNULL(PD.QtyPacked,0) AS QtyPacked ' + CHAR(13)
                 + N'      , OH.[Status] ' + CHAR(13)
                 + N'      , OH.SOStatus ' + CHAR(13)
                 + N' FROM PACKTASKDETAIL PTD WITH (NOLOCK) ' + CHAR(13)
                 + N' JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PTD.Orderkey ' + CHAR(13)
                 + N' OUTER APPLY (SELECT SUM(Qty) AS QtyPacked ' + CHAR(13)
                 + N'              FROM PACKDETAIL WITH (NOLOCK) ' + CHAR(13)
                 + N'              WHERE PickSlipNo = PTD.PickSlipNo) AS PD  ' + CHAR(13)
                 + N' WHERE PTD.TaskBatchNo = @c_TaskBatchNo ' + CHAR(13)
                 + @c_SQLCondition
                 + N' GROUP BY PTD.TaskBatchNo ' + CHAR(13)
                 + N'        , OH.Orderkey ' + CHAR(13)
                 + N'        , OH.LoadKey ' + CHAR(13)
                 + N'        , PTD.Sku ' + CHAR(13)
                 + N'        , PTD.QtyAllocated ' + CHAR(13)
                 + N'        , ISNULL(PD.QtyPacked,0) ' + CHAR(13)
                 + N'        , OH.[Status] ' + CHAR(13)
                 + N'        , OH.SOStatus ' + CHAR(13)
                 + N' ORDER BY MIN(PTD.[Status])'                                   --(Wan01) 
                 +         N', OH.Orderkey'                                         --(Wan01) 
                 
      SET @c_ExecArguments = N'  @c_TaskBatchNo   NVARCHAR(10)'
                           + N', @c_Pickslipno    NVARCHAR(10)'
                           + N', @c_Orderkey      NVARCHAR(10)'
                           
      EXEC sp_ExecuteSql   @c_SQL     
                         , @c_ExecArguments    
                         , @c_TaskBatchNo
                         , @c_PickSlipNo
                         , @c_Orderkey      
   END

   QUIT_SP:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO