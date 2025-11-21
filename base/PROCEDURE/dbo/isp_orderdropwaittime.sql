SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*-------------------------------------------------------------------------------------------------------*/
/* Stored Procedure: isp_OrderDropWaitTime                                                              */        
/* Creation Date: 23-September-2016                                                                      */        
/* Copyright: LF LOGISTICS                                                                               */        
/* Written by: JayLim                                                                                    */        
/*                                                                                                       */        
/* Purpose: Auto Update Orders.Status if wait time pass timelimit                                        */        
/*                                                                                                       */        
/* Called By: BEJ - Orders Wait Time Drop                             		                              */         
/*                                                                                                       */        
/* Parameters:                                                                                           */        
/*                                                                                                       */        
/* PVCS Version: 1.0                                                                                     */        
/*                                                                                                       */        
/* Version: 5.4                                                                                          */        
/*                                                                                                       */        
/* Data Modifications:                                                                                   */        
/*                                                                                                       */        
/* Updates:                                                                                              */        
/* Date         Author    Ver. Purposes                                                                  */
/* 22-12-2016   JayLim    1.1  FBR # WMS-851  Script enhancement (Jay01)                                 */       
/*-------------------------------------------------------------------------------------------------------*/

CREATE PROCEDURE [dbo].[isp_OrderDropWaitTime]
(
   @c_storerkey       NVARCHAR(15),
   @n_status_value    NVARCHAR(1), --(Jay01)
   @n_SOstatus_value  NVARCHAR(1)  --(Jay01)
)
AS
SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF
BEGIN
   DECLARE @c_storerkeyCode   NVARCHAR(15),
           @c_timelimit       INT,
           @n_continue        INT,
           @c_orderkey        NVARCHAR(10),
           @c_externOrderKey  NVARCHAR(30),
           @b_debug           INT,
           @b_Success         int,
           @n_err             int,
           @c_errmsg          NVARCHAR(250),
           @c_ColumnsUpdated  NVARCHAR(50)

   DECLARE @t_tempOrders TABLE
           (       
           OrderKey        NVARCHAR(10),
           ExternOrderKey  NVARCHAR(30)
           )
  
   SELECT @c_timelimit = 0        
   SELECT @c_orderkey = ''       
   SELECT @c_externOrderKey = ''
   SELECT @b_debug = 0 

   IF @n_status_value = ''  OR @n_status_value IS NULL --(Jay01)
   BEGIN
      SET @n_status_value = '2'
   END
   IF @n_SOstatus_value = '' OR @n_SOstatus_value IS NULL --(Jay01)
   BEGIN
      SET @n_SOstatus_value = '0'
   END

   SELECT @c_storerkeyCode = ISNULL(LTRIM(RTRIM(storerkey)),''),
          @c_timelimit = ISNULL(LTRIM(RTRIM(CAST(Short AS INT))),'')
   FROM CODELKUP WITH (NOLOCK)
   WHERE Listname = 'MASTWAIT'
   AND Code = 'W01'

IF @b_debug = 1
   BEGIN
      PRINT 'Select from CODELKUP'
      PRINT @c_storerkeyCode + '= storerkey'
      PRINT @c_timelimit + '= timelimit'
      PRINT @c_storerkey + '= storerkey FROM job command'
   END

   IF (@c_storerkey <> @c_storerkeyCode OR @c_storerkeyCode = '')
   BEGIN
      SELECT @n_continue = 3
   END
   ELSE IF (@c_timelimit = '')
   BEGIN
      SELECT @n_continue = 3
   END
   ELSE
   BEGIN
      SELECT @n_continue = 1
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      INSERT INTO @t_tempOrders
      SELECT Orderkey, ExternOrderKey
      FROM ORDERS WITH (NOLOCK)
      WHERE Storerkey = @c_storerkey
      AND Status = '0'
      AND sostatus <> 'PENDCANC'
      AND AddDate <= DATEADD(hour, -@c_timelimit, GETDATE())

      IF @b_debug = 1
         BEGIN
            SELECT'Select from TempTable'
            SELECT * FROM @t_tempOrders
         END

      IF EXISTS (SELECT 1 FROM @t_tempOrders)
      BEGIN
         SELECT @n_continue = 1 
      END
      ELSE
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      DECLARE CUR_READ_TEMPORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey, ExternOrderKey FROM @t_tempOrders 

      OPEN CUR_READ_TEMPORDER

      FETCH NEXT FROM CUR_READ_TEMPORDER INTO @c_orderkey , @c_externOrderKey

      WHILE  @@FETCH_STATUS <> -1
      BEGIN
         UPDATE ORDERS
         SET ORDERS.Status = @n_status_value,   --(Jay01)
             ORDERS.SOStatus = @n_SOstatus_value,  --(Jay01)
             ORDERS.archivecop = NULL,
             ORDERS.EditDate = GETDATE()
         WHERE ORDERS.OrderKey = @c_orderkey
         AND ORDERS.ExternOrderKey = @c_externOrderKey

         If EXISTS (SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)
         WHERE SourceTable = 'ORDERS' 
         and configkey = 'WSSTSLOG'and sValue = '1'
         --and Tablename = 'WSCRPICKCFMCN' --(Jay01)
         and Storerkey = @c_storerkey
         and (UpdatedColumns='STATUS' OR UpdatedColumns = 'SOSTATUS') --(Jay01)
         )
         BEGIN
            
         SET @c_ColumnsUpdated = 'STATUS,SOSTATUS'

           EXECUTE dbo.isp_ITF_ntrOrderHeader   
                  @c_TriggerName = 'ntrOrderHeaderUpdate'
                , @c_SourceTable = 'ORDERS'  
                , @c_OrderKey    = @c_orderkey  
                , @c_ColumnsUpdated = @c_ColumnsUpdated
                , @b_Success = @b_Success OUTPUT  
                , @n_err     = @n_err    OUTPUT  
                , @c_errmsg  = @c_errmsg  OUTPUT  
         END

         IF @b_debug = 1
         BEGIN
            PRINT 'Select from TempTable'
            PRINT @c_orderkey + '= orderkey ,'+ @c_externOrderKey + '= externorderkey' 
         END

         FETCH NEXT FROM CUR_READ_TEMPORDER INTO @c_orderkey , @c_externOrderKey
      END
      CLOSE CUR_READ_TEMPORDER
      DEALLOCATE CUR_READ_TEMPORDER
   END
   
END

GRANT EXECUTE ON [dbo].[isp_OrderDropWaitTime] TO nSQL 

GO