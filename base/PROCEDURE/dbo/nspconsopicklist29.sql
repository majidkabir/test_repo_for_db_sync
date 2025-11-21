SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  nspConsoPickList29                                 */  
/* Creation Date:  09-Oct-2010                                          */  
/* Copyright: IDS                                                       */  
/* Written by:  SHONG                                                   */  
/*                                                                      */  
/* Purpose:                                                             */  
/*           (modified from nspConsoPickList26                          */  
/* Input Parameters:  @a_s_LoadKey  - (LoadKey)                         */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  Report                                               */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:  r_dw_consolidated_pick29_2                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROC [dbo].[nspConsoPickList29](@a_s_LoadKey NVARCHAR(10))  
 AS  
BEGIN
    SET NOCOUNT ON  
    SET ANSI_NULLS OFF  
    SET QUOTED_IDENTIFIER OFF  
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @c_CurrOrderKey   NVARCHAR(10)
           ,@n_err            INT
           ,@n_continue       INT
           ,@c_PickHeaderKey  NVARCHAR(10)
           ,@b_success        INT
           ,@c_errmsg         NVARCHAR(255)
           ,@n_StartTranCnt   INT   
    
    SET @n_StartTranCnt = @@TRANCOUNT  
    SET @n_continue = 1 
    
    /* Start Modification */ 
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order  
    SET @c_PickHeaderKey = ''  
    
    IF NOT EXISTS(
           SELECT PickHeaderKey
           FROM   PICKHEADER WITH (NOLOCK)
           WHERE  ExternOrderKey = @a_s_LoadKey
           AND    Zone = '7'
       )
    BEGIN
        SET @b_success = 0 
        
        EXECUTE nspg_GetKey 
        'PICKSLIP', 
        9, 
        @c_PickHeaderKey OUTPUT, 
        @b_success OUTPUT, 
        @n_err OUTPUT, 
        @c_errmsg OUTPUT  
        
        IF @b_success<>1
        BEGIN
            SET @n_continue = 3
        END  
        
        IF @n_continue=1
        OR @n_continue=2
        BEGIN
            SET @c_PickHeaderKey = 'P'+@c_PickHeaderKey  
            
            INSERT INTO PICKHEADER
              (PickHeaderKey ,ExternOrderKey,PickType,Zone)
            VALUES
              (@c_PickHeaderKey,@a_s_LoadKey,'1','7')  
            
            SET @n_err = @@ERROR  
            
            IF @n_err<>0
            BEGIN
                SET @n_continue = 3  
                SET @n_err = 63501  
                SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                    ': Insert Into PICKHEADER Failed. (nspConsoPickList29)'
            END
        END-- @n_continue = 1 or @n_continue = 2
    END
    ELSE
    BEGIN
        SELECT @c_PickHeaderKey = PickHeaderKey
        FROM   PickHeader WITH (NOLOCK)
        WHERE  ExternOrderKey = @a_s_LoadKey
        AND    Zone = '7'
    END  
    
    IF ISNULL(RTRIM(@c_PickHeaderKey) ,'')=''
    BEGIN
        SET @n_continue = 3  
        SET @n_err = 63502  
        SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
            ': Get LoadKey Failed. (nspConsoPickList29)'
    END  
    
    IF @n_continue=1 OR @n_continue=2
    BEGIN
        SELECT LoadPlanDetail.LoadKey
              ,PICKHeader.PickHeaderKey
              ,LoadPlan.Route
              ,LoadPlan.AddDate
              ,PICKDETAIL.Loc
              ,PICKDETAIL.Sku
              ,PICKDETAIL.Qty
              ,SKU.DESCR
              ,PACK.CaseCnt
              ,PACK.PackKey
              ,(
                   SELECT SUM(OpenQty)
                   FROM   ORDERDETAIL WITH (NOLOCK)
                   WHERE  ORDERDETAIL.Loadkey = LOADPLANDETAIL.LoadKey
               ) AS TotalQtyOrdered
              ,(
                   SELECT SUM(QtyAllocated+QtyPicked+ShippedQty)
                   FROM   ORDERDETAIL WITH (NOLOCK)
                   WHERE  ORDERDETAIL.Loadkey = LOADPLANDETAIL.LoadKey
               ) AS TotalQtyAllocated
              ,Pack.PackUOM3 AS UOM3
              ,ISNULL(LTRIM(RTRIM(SKU.PrePackIndicator)) ,'') AS 
               PrePackIndicator
              ,(SKU.PackQtyIndicator) AS PackQtyIndicator
              ,SKU.Size
              ,CASE 
                    WHEN SKUxLOC.LocationType<>'PICK' THEN 'BULK'
                    ELSE 'PICK'
               END AS LocationType
              ,ISNULL(SKU.Busr6 ,'') 
        FROM   LOADPLAN WITH (NOLOCK)
               INNER JOIN LoadPlanDetail WITH (NOLOCK)
                    ON  (LOADPLAN.LoadKey=LoadPlanDetail.LoadKey)
               INNER JOIN PICKDETAIL WITH (NOLOCK)
                    ON  (LoadPlanDetail.OrderKey=PICKDETAIL.OrderKey)
               INNER JOIN SKU WITH (NOLOCK)
                    ON  (SKU.StorerKey=PICKDETAIL.Storerkey)
        AND             (SKU.Sku=PICKDETAIL.Sku)
               INNER JOIN PACK WITH (NOLOCK)
                    ON  (PACK.PackKey=SKU.PACKKey)
               INNER JOIN PICKHEADER
                    ON  (PICKHEADER.ExternOrderKey=LOADPLAN.LoadKey)
               INNER JOIN LOT WITH (NOLOCK)
                    ON  (PICKDETAIL.LOT=LOT.LOT)
               INNER JOIN SKUxLOC WITH (NOLOCK)
                    ON  (SKUxLOC.Storerkey=SKU.Storerkey)
        AND             (SKUxLOC.SKU=SKU.SKU)
        AND             (SKUxLOC.Loc=PICKDETAIL.Loc)
        WHERE  PICKHeader.PickHeaderKey = @c_PickHeaderKey
        AND    PICKDETAIL.QTY>0 
    END -- @n_continue = 1 or @n_continue = 2  
    
    
    IF @n_continue=3 -- Error Occured - Process And Return
    BEGIN
        EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList29' 
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
        RETURN
    END
    ELSE
    BEGIN
        SELECT @b_success = 1  
        WHILE @@TRANCOUNT>@n_StartTranCnt
        BEGIN
            COMMIT TRAN
        END 
        RETURN
    END
END /* main procedure */  

GO