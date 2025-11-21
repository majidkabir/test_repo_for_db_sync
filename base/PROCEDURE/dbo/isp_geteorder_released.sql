SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetEOrder_Released                                  */
/* Creation Date: 09-MAY-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1719 - ECOM Nov 11 - Order Management screen            */
/*        :                                                             */
/* Called By: d_dw_eorder_released                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2018-08-22  Wan01    1.1   Performance tune                          */
/************************************************************************/
CREATE PROC [dbo].[isp_GetEOrder_Released]  
           @c_Storerkey        NVARCHAR(15)
         , @c_Facility         NVARCHAR(5)
         , @c_ReleaseGroup     NVARCHAR(30)
         , @dt_StartDate       DATETIME = NULL
         , @dt_EndDate         DATETIME = NULL
         , @c_DateMode         NVARCHAR(10)
         , @c_UsrStorerkey     NVARCHAR(250)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
            
         , @c_SQL             NVARCHAR(MAX) 
         , @c_SQLParms        NVARCHAR(MAX)            

         , @c_TSecureDB       NVARCHAR(50)
         , @c_UserName        NVARCHAR(20)

         , @b_SingleStorer    BIT          
          
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   SET @c_UserName = SUSER_SNAME()
   --(Wan01) - START
   SET @b_SingleStorer = 0
   IF @c_UsrStorerkey <> '' AND CHARINDEX(',', @c_UsrStorerkey) > 0
   BEGIN
      SET @b_SingleStorer = 0
   END

   SET @c_SQL = N'SELECT DISTINCT'                                                        -- (Wan01)
              + '  BL.Facility'
              + ' ,BLD.Loadkey'
              + ' ,BLD.AddDate'
              + ' ,BLD.AddWho'
              + ' ,BL.BuildParmCode'
              + ' ,BLD.TotalOrderCnt'
              + ' ,BLD.TotalOrderQty'
              + ' ,LP.Status'
              + ' ,''N'' selectrow'
              + ' ,''N'' selectrowctrl'
              + ' ,''    '' rowfocusindicatorcol' 
              + ' FROM BUILDLOADLOG       BL  WITH (NOLOCK)'
              + ' JOIN BUILDLOADDETAILLOG BLD WITH (NOLOCK) ON (BL.BatchNo = BLD.BatchNo)'
              + ' JOIN LOADPLANDETAIL     LP  WITH (NOLOCK) ON (BLD.Loadkey= LP.Loadkey)'  -- (Wan01)
              + ' WHERE BL.BuildParmGroup = @c_ReleaseGroup'  
              + ' AND BL.Storerkey = @c_Storerkey' 
              + CASE WHEN @c_UsrStorerkey = '' AND @c_Storerkey <> '' 
                     --THEN ' AND BL.Storerkey = @c_Storerkey AND BLD.AddWho = @c_UserName' 
                     THEN ' AND BLD.AddWho = @c_UserName'     
                     WHEN @c_UsrStorerkey <>'' AND @b_SingleStorer = 1
                     THEN ' AND BL.Storerkey = @c_UsrStorerkey'  
                     WHEN @c_UsrStorerkey <>'' AND @b_SingleStorer = 0
                     THEN ' AND BL.Storerkey IN (''' + REPLACE(@c_UsrStorerkey, ',', ''',''') + ''')'  
                     ELSE ''
                     END
              + CASE WHEN @c_Facility  = '' 
                     THEN '' 
                     ELSE ' AND BL.Facility = @c_Facility'     
                     END
              + ' AND   EXISTS ( SELECT 1' 
              +               '  FROM ORDERS OH WITH (NOLOCK)'
              +               '  WHERE OH.Orderkey = LP.Orderkey'  -- Wan01
              +     CASE WHEN @c_DateMode = '1'
                         THEN ' AND  OH.AddDate   BETWEEN @dt_StartDate AND @dt_EndDate '
                         ELSE ' AND  OH.OrderDate BETWEEN @dt_StartDate AND @dt_EndDate ' 
                         END
              +               ' )'

   SET @c_SQLParms = N'@c_Storerkey       NVARCHAR(15)'
                   + ',@c_Facility        NVARCHAR(5)'
                   + ',@c_ReleaseGroup    NVARCHAR(30)'
                   + ',@dt_StartDate      DATETIME'
                   + ',@dt_EndDate        DATETIME'
                   + ',@c_UserName        NVARCHAR(20)'
                   + ',@c_UsrStorerkey    NVARCHAR(250)'

   EXECUTE sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms
                        , @c_Storerkey
                        , @c_Facility
                        , @c_ReleaseGroup
                        , @dt_StartDate
                        , @dt_EndDate
                        , @c_UserName
                        , @c_UsrStorerkey

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO