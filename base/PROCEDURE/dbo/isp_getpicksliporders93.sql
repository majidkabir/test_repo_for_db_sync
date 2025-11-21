SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Proc : isp_GetPickSlipOrders93                                   */  
/* Creation Date:                                                          */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: Pick Slip for TRIPLE                                           */  
/*                                                                         */  
/*                                                                         */  
/* Usage:                                                                  */  
/*                                                                         */  
/* Local Variables:                                                        */  
/*                                                                         */  
/* Called By: r_dw_print_pickorder93                                       */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author      Ver   Purposes                                  */  
/***************************************************************************/  
  
CREATE PROC [dbo].[isp_GetPickSlipOrders93] (
           @c_loadkey NVARCHAR(10), 
           @b_debug   INT = 0           )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  @c_pickheaderkey        NVARCHAR(10),  
            @n_continue             INT,  
            @c_errmsg               NVARCHAR(255),  
            @b_success              INT,  
            @n_err                  INT,
            @n_FixturesCnt          INT,
            @c_TempSKUGrp           NVARCHAR(10)


   DECLARE @n_starttcnt INT  
   SELECT  @n_starttcnt = @@TRANCOUNT  
   SET     @n_continue  = 1
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  

   CREATE TABLE #OrderdetailRef
   ( rowid             INT NOT NULL IDENTITY(1,1),
     Orderkey          NVARCHAR(10),
     OrderLineNumber   NVARCHAR(5),
     SKU               NVARCHAR(20),
     SKUGroup          NVARCHAR(10) )

   IF (@n_continue = 1 OR @n_continue = 2) AND @b_debug = 0
   BEGIN
      INSERT INTO #OrderdetailRef (Orderkey, OrderLineNumber, SKU, SKUGroup)
      SELECT ORD.Orderkey, OD.OrderLineNumber, OD.SKU, SKU.SKUGroup
      FROM ORDERS ORD (NOLOCK) 
      JOIN ORDERDETAIL OD (NOLOCK) ON ORD.ORDERKEY = OD.ORDERKEY
      JOIN SKU (NOLOCK) ON SKU.SKU = OD.SKU AND ORD.STORERKEY = SKU.STORERKEY
      WHERE ORD.Loadkey = @c_loadkey
      ORDER BY ORD.Orderkey, OD.OrderLineNumber
   END

   --For debug only START
   IF (@n_continue = 1 OR @n_continue = 2) AND @b_debug = 1
   BEGIN
      INSERT INTO #OrderdetailRef (Orderkey, OrderLineNumber, SKU, SKUGroup)
      SELECT ORD.Orderkey, OD.OrderLineNumber, OD.SKU, CASE WHEN OD.OrderLineNumber = '00003' THEN 'Fixtures' ELSE SKU.SKUGroup END
      FROM ORDERS ORD (NOLOCK) 
      JOIN ORDERDETAIL OD (NOLOCK) ON ORD.ORDERKEY = OD.ORDERKEY
      JOIN SKU (NOLOCK) ON SKU.SKU = OD.SKU AND ORD.STORERKEY = SKU.STORERKEY
      WHERE ORD.Loadkey = @c_loadkey
      ORDER BY ORD.Orderkey, OD.OrderLineNumber
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND @b_debug = 2
   BEGIN
      INSERT INTO #OrderdetailRef (Orderkey, OrderLineNumber, SKU, SKUGroup)
      SELECT ORD.Orderkey, OD.OrderLineNumber, OD.SKU, 'Fixtures' --SKU.SKUGroup
      FROM ORDERS ORD (NOLOCK) 
      JOIN ORDERDETAIL OD (NOLOCK) ON ORD.ORDERKEY = OD.ORDERKEY
      JOIN SKU (NOLOCK) ON SKU.SKU = OD.SKU AND ORD.STORERKEY = SKU.STORERKEY
      WHERE ORD.Loadkey = @c_loadkey
      ORDER BY ORD.Orderkey, OD.OrderLineNumber
   END
   --For debug only END
   
   --select * from #OrderdetailRef

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @n_FixturesCnt = COUNT(1)
      FROM #OrderdetailRef
      WHERE SKUGroup = 'FIXTURES'

      IF (@n_FixturesCnt = 0)
      BEGIN
         SELECT @c_loadkey AS Loadkey, 'Non-Fixtures' AS [Status]
      END
      ELSE --Fixtures
      BEGIN
         SELECT @c_TempSKUGrp = Count(DISTINCT SKUGroup)
         FROM #OrderdetailRef

         IF (@c_TempSKUGrp > 1)
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 60000   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fixtures and Non-Fixtures are mixed. Please check! (isp_GetPickSlipOrders93)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
            GOTO QUIT_SP
         END
         ELSE
         BEGIN
            SELECT @c_loadkey AS Loadkey, 'FIXTURES' AS [Status]
         END
      END
   END

QUIT_SP:
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPickSlipOrders93'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END 
  
   WHILE @@TRANCOUNT < @n_starttcnt  
   BEGIN  
      BEGIN TRAN  
   END  
END  


GO