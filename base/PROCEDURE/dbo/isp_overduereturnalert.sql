SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_OverdueReturnAlert                             */  
/* Creation Date: 02-Aug-2019                                           */  
/* Copyright: LF                                                        */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose:  Check Overdue Return (Initially for HM)                    */
/*                                                                      */  
/* Called By: Popuate Orders for Trade Return                           */    
/*                                                                      */
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

CREATE PROCEDURE [dbo].[isp_OverdueReturnAlert]
      @c_Storerkey        NVARCHAR(15)
   ,  @c_Facility         NVARCHAR(15)   = '' 
   ,  @c_Orderkey         NVARCHAR(10)  
   ,  @c_IsArch           NVARCHAR(10)   = 'N'
   ,  @b_Success          INT            OUTPUT 
   ,  @n_Err              INT            OUTPUT 
   ,  @c_ErrMsg           NVARCHAR(250)  OUTPUT
   ,  @c_Option5          NVARCHAR(4000) OUTPUT
   ,  @b_debug            INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @n_Continue            INT,
            @n_StartTCnt           INT,
            @c_Option1             NVARCHAR(50) = '', 
            @c_Option2             NVARCHAR(50) = '', 
            @c_Option3             NVARCHAR(50) = '', 
            @c_Option4             NVARCHAR(50) = '', 
            @c_OverdueReturnAlert  NVARCHAR(10) = '',
            @dt_ShipDate           DATETIME,
            @c_SQL                 NVARCHAR(4000) = '',
            @c_ArchiveDB           NVARCHAR(1000) = '',
            @c_ExecArgs            NVARCHAR(1000) = ''

   CREATE TABLE #ShipDate
   ( Shipdate    DATETIME )
            
   SELECT @n_continue = 1, @n_Err = 0, @b_Success = 1, @c_ErrMsg = '', @n_StartTCnt = @@TRANCOUNT

   IF @c_IsArch = 'Y'
   BEGIN
      SELECT @c_ArchiveDB = ISNULL(RTRIM(NSQLValue),'') + '.' FROM NSQLCONFIG WITH (NOLOCK)
      WHERE ConfigKey='ArchiveDBName'
   END
   ELSE
   BEGIN
      SET @c_ArchiveDB = ''
   END

   SET @c_SQL = N' INSERT INTO #ShipDate '
              + '  SELECT TOP 1 ISNULL(MBOL.ShipDate,''1900-01-01 00:00:00.000'') '
              + '  FROM ' + @c_ArchiveDB + ' dbo.MBOL MBOL(NOLOCK) '
              + '  JOIN ' + @c_ArchiveDB + ' dbo.MBOLDETAIL MBOLDETAIL (NOLOCK) ON MBOL.MBOLKEY = MBOLDETAIL.MBOLKEY '
              + '  JOIN ' + @c_ArchiveDB + ' dbo.ORDERS ORDERS (NOLOCK) ON ORDERS.ORDERKEY = MBOLDETAIL.ORDERKEY '
              + '  WHERE ORDERS.ORDERKEY = @c_Orderkey '

   SET @c_ExecArgs = N' @c_Orderkey           NVARCHAR(10) '    


   EXECUTE sp_ExecuteSQL @c_SQL
                       , @c_ExecArgs
                       , @c_Orderkey
   --PRINT @c_SQL

   SELECT TOP 1 @dt_ShipDate = Shipdate
   FROM #ShipDate

   IF @b_debug = 1
   BEGIN
      SELECT @dt_ShipDate, @c_Orderkey
   END

   EXEC nspGetRight   
      @c_Facility              -- facility  
   ,  @c_Storerkey             -- Storerkey  
   ,  NULL                     -- Sku  
   ,  'Overdue_Return_Alert'   -- Configkey  
   ,  @b_Success               OUTPUT   
   ,  @c_OverdueReturnAlert    OUTPUT   
   ,  @n_Err                   OUTPUT   
   ,  @c_ErrMsg                OUTPUT 
   ,  @c_Option1               OUTPUT
   ,  @c_Option2               OUTPUT  
   ,  @c_Option3               OUTPUT  
   ,  @c_Option4               OUTPUT  
   ,  @c_Option5               OUTPUT
                                       
   IF @b_success <> 1  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 61000   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_OverdueReturnAlert)'   
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT  
   END 

   IF(ISNUMERIC(@c_Option1) <> 1)
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 61005   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Option1 is not a number. (isp_OverdueReturnAlert)'   
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT 
   END

   IF(ISNULL(@c_Option5,'') = '')
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 61010   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Option5 not maintained. (isp_OverdueReturnAlert)'   
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT 
   END

   IF (@c_OverdueReturnAlert = 1)
   BEGIN
      IF (DATEDIFF(DD, CAST(@dt_ShipDate AS DATE), DATEADD(DD, -1,  GetDate())) > @c_Option1)
      BEGIN  
         SET @n_continue = 3
         GOTO QUIT
      END
      ELSE 
      BEGIN
         SET @c_Option5 = ''
      END
   END
     
QUIT:
   IF OBJECT_ID('tempdb..#ShipDate') IS NOT NULL
      DROP TABLE #ShipDate

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
  
      --EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_OverdueReturnAlert'  
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
      BEGIN TRAN;     


END -- End Procedure

GO