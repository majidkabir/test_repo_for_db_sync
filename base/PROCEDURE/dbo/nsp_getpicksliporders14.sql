SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipOrders14                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Archive UCC Records that already Packed in Pick n Pack      */
/*          UCC Status change to 6 when UCC# was scanned in PnP         */
/* Called By: Schedule Job                                              */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author      Purposes                                    */
/* 10-Aug-2004  Shong       SOS# 24821- Change Request                  */
/* 26-Nov-2013  TLTING      Change user_name() to SUSER_SNAME()         */
/* 26-Feb-2014  Shong       SOS# 304709 - Replace the SKU with AltSKU   */
/*                          When StorerConfig PickSlipWithAltSKU is On  */
/************************************************************************/
CREATE PROC [dbo].[nsp_GetPickSlipOrders14] (@c_loadkey NVARCHAR(10))
AS
BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET CONCAT_NULL_YIELDS_NULL OFF
    -- Created by YTWan on 2-July-2004 (SOS#:24821)
    
    DECLARE @c_orderkey      NVARCHAR(10)
           ,@c_pickslipno    NVARCHAR(10)
           ,@c_invoiceno     NVARCHAR(10)
           ,@c_storerkey     NVARCHAR(18)
           ,@c_consigneekey  NVARCHAR(15)
           ,@b_success       INT
           ,@n_err           INT
           ,@c_errmsg        NVARCHAR(255)
    
    SELECT PICKDETAIL.PickSlipNo
          ,PICKDETAIL.Lot
          ,PICKDETAIL.Loc
          ,PICKDETAIL.ID
          ,PickedQty = SUM(PICKDETAIL.Qty)
          ,SKU.DESCR
          ,CASE WHEN ISNULL(StorerConfig.SValue, '0') <> '1' THEN SKU.Sku ELSE SKU.ALTSKU END AS [SKU] 
          ,SKU.RetailSku
          ,SKU.STDNETWGT
          ,SKU.STDCUBE
          ,SKU.STDGROSSWGT
          ,LOTATTRIBUTE.Lottable02
          ,LOTATTRIBUTE.Lottable04
          ,ORDERS.OrderKey
          ,ORDERS.LoadKey
          ,ORDERS.StorerKey
          ,STORER.Company
          ,ORDERS.ConsigneeKey
          ,consignee.company AS C_company
          ,LOADPLAN.lpuserdefdate01
          ,ORDERS.ExternOrderKey
          ,ORDERS.Route
          ,ORDERS.PrintFlag
          ,Notes = CONVERT(NVARCHAR(250) ,ORDERS.Notes)
          ,PACK.CaseCnt
          ,PACK.InnerPack
          ,Loc.Putawayzone
          ,Prepared = CONVERT(NVARCHAR(10) ,sUSER_sNAME())
          ,LOADPLAN.Delivery_Zone 
           INTO #RESULT
    FROM ORDERS WITH (NOLOCK)
    JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
    JOIN PICKDETAIL WITH (NOLOCK) ON  PICKDETAIL.orderkey = ORDERDETAIL.orderkey
          AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber       
    JOIN LOC WITH (NOLOCK) ON  LOC.Loc = PICKDETAIL.Loc
    JOIN STORER WITH (NOLOCK) ON  ORDERS.StorerKey = STORER.StorerKey
    LEFT OUTER JOIN STORER consignee WITH (NOLOCK)
          ON  consignee.storerkey = ORDERS.consigneekey
    JOIN SKU WITH (NOLOCK) ON  SKU.StorerKey = PICKDETAIL.Storerkey
          AND SKU.Sku = PICKDETAIL.Sku
    JOIN LOTATTRIBUTE WITH (NOLOCK) ON  PICKDETAIL.Lot = LOTATTRIBUTE.Lot
    JOIN PACK WITH (NOLOCK) ON  PACK.PackKey = SKU.PackKey
    JOIN LOADPLAN WITH (NOLOCK) ON  ORDERDETAIL.Loadkey = LOADPLAN.LoadKey
    LEFT OUTER JOIN CODELKUP WITH (NOLOCK) ON  codelkup.listname = 'PRINCIPAL'
          AND codelkup.code = sku.susr3 
    LEFT OUTER JOIN StorerConfig WITH (NOLOCK) ON StorerConfig.Storerkey = ORDERS.Storerkey 
          AND StorerConfig.ConfigKey = 'PickSlipWithAltSKU' AND StorerConfig.SValue = '1'
    WHERE  ORDERS.LOADKEY = @c_loadkey 
    GROUP BY
           PICKDETAIL.PickSlipNo
          ,PICKDETAIL.Lot
          ,PICKDETAIL.ID
          ,PICKDETAIL.Loc
          ,SKU.DESCR
          ,CASE WHEN ISNULL(StorerConfig.SValue, '0') <> '1' THEN SKU.Sku ELSE SKU.ALTSKU END 
          ,SKU.RetailSku
          ,SKU.STDNETWGT
          ,SKU.STDCUBE
          ,SKU.STDGROSSWGT
          ,LOTATTRIBUTE.Lottable02
          ,LOTATTRIBUTE.Lottable04
          ,ORDERS.OrderKey
          ,ORDERS.LoadKey
          ,ORDERS.StorerKey
          ,STORER.Company
          ,ORDERS.ConsigneeKey
          ,consignee.company
          ,LOADPLAN.lpuserdefdate01
          ,ORDERS.ExternOrderKey
          ,ORDERS.Route
          ,ORDERS.PrintFlag
          ,CONVERT(NVARCHAR(250) ,ORDERS.Notes)
          ,PACK.CaseCnt
          ,PACK.InnerPack
          ,LOC.PutawayZone
          ,LOADPLAN.Delivery_Zone -- SOS# 24821- Change Request
    ORDER BY
           LOC.PutawayZone
          ,ORDERS.OrderKey
          ,ORDERS.LoadKey
    
    SELECT @c_orderkey = ''
    WHILE (1 = 1)
    BEGIN
        -- while 1
        SELECT @c_orderkey = MIN(orderkey)
        FROM   #result
        WHERE  orderkey > @c_orderkey
        AND    (pickslipno IS NULL OR pickslipno = '')
        
        IF ISNULL(@c_orderkey ,'0') = '0'
            BREAK
        
        SELECT @c_storerkey = storerkey
        FROM   #result
        WHERE  orderkey = @c_orderkey
        
        EXECUTE nspg_GetKey
        'PICKSLIP',
        9, 
        @c_pickslipno OUTPUT,
        @b_success OUTPUT,
        @n_err OUTPUT,
        @c_errmsg OUTPUT
        
        SELECT @c_pickslipno = 'P' + @c_pickslipno            
        
        INSERT PICKHEADER
          (
            pickheaderkey
           ,wavekey
           ,externorderkey
           ,orderkey
           ,zone
          )
        VALUES
          (
            @c_pickslipno
           ,@c_loadkey
           ,@c_loadkey
           ,@c_orderkey
           ,'3'
          )
        
        -- update PICKDETAIL
        UPDATE PICKDETAIL WITH (ROWLOCK)
        SET    trafficcop = NULL
              ,pickslipno = @c_pickslipno
        WHERE  orderkey = @c_orderkey
        
        -- update print flag
        UPDATE ORDERS WITH (ROWLOCK)
        SET    trafficcop = NULL
              ,printflag = 'Y'
        WHERE  orderkey = @c_orderkey
        
        IF EXISTS (
               SELECT 1
               FROM   storerconfig(NOLOCK)
               WHERE  storerkey = @c_storerkey
               AND    configkey IN ('WTS-ITF' ,'LORITF')
               AND    svalue = '1'
           )
            -- update result table
            UPDATE #RESULT
            SET    pickslipno  = @c_pickslipno
                  ,loadkey     = @c_loadkey
            WHERE  orderkey    = @c_orderkey
        ELSE
            UPDATE #RESULT
            SET    pickslipno  = @c_pickslipno
            WHERE  orderkey    = @c_orderkey
    END -- while 1
    
    -- return result set
    SELECT *
    FROM   #RESULT
    
    -- drop table
    DROP TABLE #RESULT
END

GO