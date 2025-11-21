SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Trigger: ntrShortPickLogAdd                                             */    
/* Creation Date: 11-JUNE-2012                                             */    
/* Copyright: IDS                                                          */    
/* Written by: YTWan                                                       */    
/*                                                                         */    
/* Purpose: SOS#246450:Delete short pick at MBOL & CBOL and auto pack      */  
/*                     confirm improvement                                 */    
/*                                                                         */    
/* Usage:                                                                  */    
/*                                                                         */    
/* Called By: When records Insert Into ShortPickLog                        */    
/*          : Carter Pack Confirm for Discrete Order & US Conso Order      */  
/*            If Storerconfig 'ShortPickAutoClosePack'                     */  
/*                                                                         */    
/* PVCS Version: 1.0                                                       */    
/*                                                                         */    
/* Version: 5.4                                                            */    
/*                                                                         */    
/* Modifications:                                                          */    
/* Date         Author     Ver.  Purposes                                  */    
/* 13-07-2012   James      1.1   SOS249039 - Insert short pick into virtual*/  
/*                               loc (james01)                             */  
/* 30-Jul-2014  CSCHONG    1.2   Add Lottable06-15 (CS01)                  */
/***************************************************************************/    
CREATE TRIGGER [dbo].[ntrShortPickLogAdd]  
ON [dbo].[ShortPickLog]  
FOR INSERT  
AS  
BEGIN  
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF     
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @b_Success         INT -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err             INT -- Error number returned by stored procedure or this trigger  
         , @c_errmsg          NVARCHAR(250) -- Error message returned by stored procedure or this trigger  
  
         , @n_Continue        INT  
         , @n_StartTCnt       INT -- Holds the current transaction count  
  
         , @c_Facility        NVARCHAR(5)  
         , @c_Storerkey       NVARCHAR(15)   
         , @c_SConfigkey      NVARCHAR(30)      
         , @c_SValue          NVARCHAR(10)  
  
         , @c_Orderkey        NVARCHAR(10)  
         , @c_OrderLineNumber NVARCHAR(5)  
         , @c_ConsoOrderkey   NVARCHAR(30)  
  
         , @c_Loadkey         NVARCHAR(10)  
         , @c_SKU             NVARCHAR(20)  
         , @c_FromLOC         NVARCHAR(10)  
         , @c_VShortLOC       NVARCHAR(10)  
         , @c_ID              NVARCHAR(18)  
         , @c_Lot             NVARCHAR(10)  
         , @c_PackKey         NVARCHAR(10)  
         , @c_PackUOM3        NVARCHAR(10)  
         , @n_QTYShort        INT  
           
  
--         , @n_SumPickQty      INT  
--         , @n_SumPackQty      INT  
  
  
              
   SET @n_Continue         = 1  
   SET @n_StartTCnt        = @@TRANCOUNT  
  
   SET @c_Facility         = ''  
   SET @c_Storerkey        = ''  
   SET @c_SConfigkey       = 'ShortPickAutoClosePack'  
   SET @c_SValue           = ''  
  
   SET @c_Orderkey         = ''  
   SET @c_OrderLineNumber  = ''  
   SET @c_ConsoOrderkey    = ''  
     
   SET @c_Loadkey          = ''  
--   SET @n_SumPickQty       = 0  
--   SET @n_SumPackQty       = 0  
  
   SELECT @c_Storerkey = Storerkey  
         ,@c_Orderkey  = Orderkey  
         ,@c_OrderLineNumber = OrderLineNumber  
         ,@c_SKU = SKU  
         ,@c_FromLOC = LOC  
         ,@c_ID = ID  
         ,@c_Lot = LOT  
         ,@n_QTYShort = Qty   
   FROM INSERTED  

   Execute nspGetRight @c_Facility             -- facility  
                     , @c_Storerkey            -- Storerkey  
                     , NULL                    -- Sku  
                     , @c_SConfigkey            -- Configkey  
                     , @b_Success               OUTPUT  
                     , @c_SValue                OUTPUT  
                     , @n_Err                   OUTPUT  
                     , @c_Errmsg                OUTPUT  
   
   IF @b_success <> 1  
   BEGIN  
      SET @n_continue = 3
      SET @n_Err      = 64000
      SET @c_errmsg = 'ntrShortPickLogAdd ' + ISNULL(RTrim(@c_errmsg),'')  
      GOTO QUIT
   END  
   
   IF @c_SValue = '1'   
   BEGIN  
      SELECT @c_ConsoOrderkey = ISNULL(RTRIM(ConsoOrderkey),'')  
            ,@c_Loadkey =  ISNULL(RTRIM(Loadkey),'')   
      FROM   ORDERDETAIL WITH (NOLOCK)  
      WHERE  Orderkey = @c_Orderkey  
      AND    OrderLineNumber = @c_OrderLineNumber  
     
      IF @c_ConsoOrderkey = ''  
      BEGIN  
         IF EXISTS ( SELECT 1      
                     FROM PACKHEADER WITH (NOLOCK) WHERE Orderkey = @c_Orderkey  
                   )  
         BEGIN  
            IF EXISTS ( SELECT 1  
                        FROM PICKDETAIL  WITH (NOLOCK)  
                        WHERE PICKDETAIL.Orderkey = @c_Orderkey  
                        AND  PICKDETAIL.STATUS = '4'   
                      )  
            BEGIN  
               GOTO QUIT  
            END  
     
            --Normal Packing  
            IF NOT EXISTS (  
                           SELECT 1  
                           FROM PICKDETAIL WITH (NOLOCK)  
                           JOIN (SELECT PACKDETAIL.Storerkey  
                                       ,PACKDETAIL.Sku  
                                       ,SumPackQty = ISNULL(SUM(PACKDETAIL.Qty),0)  
                                 FROM PACKHEADER WITH (NOLOCK)  
                                 JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
                                 WHERE PACKHEADER.Orderkey = @c_Orderkey  
                                 GROUP BY PACKDETAIL.Storerkey, PACKDETAIL.Sku  
                                 ) PCK  
                           ON (PICKDETAIL.Storerkey = PCK.Storerkey) AND (PICKDETAIL.Sku = PCK.Sku)  
                           WHERE ORDERKEY = @c_Orderkey  
                           GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.Sku, PCK.SumPackQty  
                           HAVING ISNULL(SUM(PICKDETAIL.Qty),0) <> SumPackQty  
                           )  
            BEGIN  
               UPDATE PACKHEADER WITH (ROWLOCK)  
               SET Status = '9'  
               WHERE  Orderkey = @c_Orderkey  
  
               SET @n_err = @@ERROR   
               IF @n_err <> 0  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_err = 65001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Pack confirmed Failed. (ntrPICKDETAILDelete)'   
                               + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
                  GOTO QUIT  
               END   
            END   
         END  
         ELSE  
         BEGIN  
            IF EXISTS ( SELECT 1      
                        FROM PACKHEADER WITH (NOLOCK) WHERE Loadkey = @c_Loadkey  
                      )  
            BEGIN  
               IF EXISTS ( SELECT 1  
                           FROM PICKDETAIL  WITH (NOLOCK)  
                           JOIN ORDERS WITH (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)  
                           WHERE ORDERS.Loadkey = @c_Loadkey  
                           AND  PICKDETAIL.STATUS = '4'   
                         )  
               BEGIN  
                  GOTO QUIT  
               END  
  
               IF NOT EXISTS (  
                              SELECT 1  
                              FROM PICKDETAIL WITH (NOLOCK)  
                              JOIN ORDERS WITH (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)  
                              JOIN (SELECT PACKDETAIL.Storerkey  
                                          ,PACKDETAIL.Sku  
                                          ,SumPackQty = ISNULL(SUM(PACKDETAIL.Qty),0)  
                                    FROM PACKHEADER WITH (NOLOCK)  
                                    JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
                                    WHERE PACKHEADER.Loadkey = @c_Loadkey  
                                    GROUP BY PACKDETAIL.Storerkey, PACKDETAIL.Sku  
                                    ) PCK  
                              ON (PICKDETAIL.Storerkey = PCK.Storerkey) AND (PICKDETAIL.Sku = PCK.Sku)  
                              WHERE ORDERS.Loadkey = @c_Loadkey  
                              GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.Sku, PCK.SumPackQty  
                              HAVING ISNULL(SUM(PICKDETAIL.Qty),0) <> SumPackQty  
                              )  
               BEGIN  
                  UPDATE PACKHEADER WITH (ROWLOCK)  
                  SET Status = '9'  
                  WHERE Loadkey = @c_Loadkey  
  
                  SET @n_err = @@ERROR   
                  IF @n_err <> 0  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @n_err = 65002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Pack confirmed Failed. (ntrPICKDETAILDelete)'   
                                  + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
                     GOTO QUIT  
                  END   
               END   
            END  
         END  
      END  
      ELSE  
      BEGIN  
         IF EXISTS ( SELECT 1  
                     FROM PICKDETAIL  WITH (NOLOCK)  
                     JOIN ORDERDETAIL WITH (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey)  
                                                    AND(PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)  
                     WHERE ORDERDETAIL.ConsoOrderkey = @c_ConsoOrderkey  
                     AND  PICKDETAIL.STATUS = '4' 
                   )  
         BEGIN  
            GOTO QUIT  
         END  
  
         --USA Conso Packing  
         IF NOT EXISTS (  
                        SELECT 1  
                        FROM ORDERDETAIL WITH (NOLOCK)  
                        JOIN PICKDETAIL  WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey)  
                                                       AND(PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)  
                        JOIN (SELECT PACKDETAIL.Storerkey  
                                    ,PACKDETAIL.Sku  
                                    ,SumPackQty = ISNULL(SUM(PACKDETAIL.Qty),0)  
                              FROM PACKHEADER WITH (NOLOCK)  
                              JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
                              WHERE PACKHEADER.ConsoOrderkey = @c_ConsoOrderkey  
                              GROUP BY PACKDETAIL.Storerkey, PACKDETAIL.Sku  
                              ) PCK  
                        ON (PICKDETAIL.Storerkey = PCK.Storerkey) AND (PICKDETAIL.Sku = PCK.Sku)  
                        WHERE ORDERDETAIL.ConsoOrderkey = @c_ConsoOrderkey  
                                    GROUP BY PICKDETAIL.Storerkey, PICKDETAIL.Sku, PCK.SumPackQty  
                                    HAVING ISNULL(SUM(PICKDETAIL.Qty),0) <> SumPackQty  
                        )  
         BEGIN  
            UPDATE PACKHEADER WITH (ROWLOCK)  
            SET Status = '9'  
            WHERE  ConsoOrderkey = @c_ConsoOrderkey  
  
            SET @n_err = @@ERROR   
            IF @n_err <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 65003   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Pack confirmed Failed. (ntrPICKDETAILDelete)'   
                            + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
               GOTO QUIT  
            END   
         END   
      END  
   
  
   END  
  
   -- Insert into virtual short pik loc when short pick (james01)  
   SET @c_SValue = ''  
   Execute nspGetRight @c_Facility             -- facility  (james01)  
                     , @c_Storerkey            -- Storerkey    
                     , NULL                    -- Sku    
                     , 'MoveShortPickQty'   -- Configkey    
                     , @b_Success               OUTPUT    
                     , @c_SValue                OUTPUT    
                     , @n_Err                   OUTPUT    
                     , @c_Errmsg                OUTPUT    
     
   IF @b_success <> 1    
   BEGIN    
      SET @n_continue = 3  
      SET @n_Err      = 64004  
      SET @c_errmsg = 'ntrShortPickLogAdd ' + ISNULL(RTrim(@c_errmsg),'')    
      GOTO QUIT  
   END    
  
   IF @c_SValue = '1'  
   BEGIN  
      SELECT   
         @c_PackKey = P.PackKey,   
         @c_PackUOM3 = P.PackUOM3   
      FROM dbo.SKU S WITH (NOLOCK)   
      JOIN dbo.PACK P WITH (NOLOCK) ON S.PackKey = P.PackKey  
      WHERE Storerkey = @c_StorerKey  
         AND SKU = @c_SKU  
  
      SELECT @c_Facility = Facility  
      FROM dbo.Orders WITH (NOLOCK)  
      WHERE Storerkey = @c_StorerKey  
         AND OrderKey = @c_Orderkey  
  
      SELECT @c_VShortLOC = Short FROM CODELKUP with (NOLOCK)   
      WHERE ListName = 'WCSROUTE'   
         AND Code = 'VSHORTLOC'  
  
      IF ISNULL(@c_VShortLOC, '') = ''  
      BEGIN    
         SET @n_continue = 3  
         SET @n_Err      = 65005  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Virtual Short Pick Location not setup. (ntrPICKDETAILDelete)'   
                             + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
         GOTO QUIT  
      END    
  
      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)   
                     WHERE LOC = @c_VShortLOC   
                     AND Facility = @c_Facility)  
      BEGIN    
         SET @n_continue = 3  
         SET @n_Err      = 65006  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Virtual Short Pick Location not valid. (ntrPICKDETAILDelete)'   
                             + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
         GOTO QUIT  
      END    
  
    
      -- Move LOTxLOCxID  
      EXEC dbo.nspItrnAddMove  
           @n_ItrnSysId     = NULL            
         , @c_StorerKey     = @c_StorerKey    
         , @c_Sku           = @c_SKU       
         , @c_Lot           = @c_LOT           
         , @c_FromLoc       = @c_FromLOC           
         , @c_FromID        = @c_ID            
         , @c_ToLoc         = @c_VShortLOC         
         , @c_ToID          = @c_ID   
         , @c_Status        = ''              
         , @c_lottable01    = ''              
         , @c_lottable02    = ''              
         , @c_lottable03    = ''              
         , @d_lottable04    = ''              
         , @d_lottable05    = ''
			, @c_lottable06    = ''			--CS01            
         , @c_lottable07    = ''       --CS01       
         , @c_lottable08    = ''			--CS01
			, @c_lottable09    = ''       --CS01       
         , @c_lottable10    = ''       --CS01       
         , @c_lottable11    = ''			--CS01
			, @c_lottable12    = ''			--CS01
			, @d_lottable13    = ''       --CS01      
         , @d_lottable14    = ''       --CS01       
         , @d_lottable15    = ''       --CS01       
         , @n_casecnt       = 0               
         , @n_innerpack     = 0               
         , @n_qty           = @n_QTYShort      
         , @n_pallet        = 0               
         , @f_cube          = 0               
         , @f_grosswgt      = 0               
         , @f_netwgt        = 0               
         , @f_otherunit1    = 0               
         , @f_otherunit2    = 0               
         , @c_SourceKey     = ''              
         , @c_SourceType    = 'ntrShortPickLogAdd'    
         , @c_PackKey       = @c_PackKey       
         , @c_UOM           = @c_PackUOM3      
         , @b_UOMCalc       = 1               
         , @d_EffectiveDate = ''              
         , @c_itrnkey       = ''              
         , @b_Success       = @b_Success      
         , @n_err           = @n_Err        
         , @c_errmsg        = @c_ErrMsg        
  
      IF @n_Err <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 65007   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ITRN Add Move Failed. (ntrPICKDETAILDelete)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
         GOTO QUIT  
      END   
   END  
     
   QUIT:  
   IF @n_continue=3 -- Error Occured - Process And Return  
    BEGIN  
        IF @@TRANCOUNT = 1  
        AND @@TRANCOUNT >= @n_StartTCnt  
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
        EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrShortPickLogAdd"   
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012   
        RETURN  
    END  
    ELSE  
    BEGIN  
        WHILE @@TRANCOUNT > @n_StartTCnt  
        BEGIN  
            COMMIT TRAN  
        END   
        RETURN  
    END  
END    
      

GO