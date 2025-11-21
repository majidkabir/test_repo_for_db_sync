SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: ispPnp_PackSKU                                      */    
/* Creation Date  : 2005-03-25                                          */    
/* Copyright      : IDS                                                 */    
/* Written by     : Shong                                               */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/*                                                                      */    
/*                                                                      */    
/* Called from: NIKE TAIWAN Scan and Pack Module                        */    
/*                                                                      */    
/*                                                                      */    
/* Exceed version: 7.0                                                  */    
/* Revision: 1.2                                                        */    
/*                                                                      */    
/* Updates:                                                             */      
/* Date         Author    Ver.  Purposes                                */      
/* 05-May-2005  Shong     1.0   NSC Project. Standardize the LabelNo    */    
/*                              and Label Line Insertion.               */    
/* 25-Sep-2014  NJOW01    1.1   321611-Configurable generate label no   */    
/* 13-MAY-2106  Wan01     1.2   Specify SP parameters                   */    
/* 24-JAN-2018  CSCHONG   1.3   WMS-3389- cater for conso orders (CS01) */   
/* 05-MAR-2019  CSCHONG   1.4   WMS-8072 - pass in cartonno to          */  
/*                              isp_GenUCCLabelNo_Std (CS02)            */   
/* 18-NOV-2021  SPChin    1.5   JSM-32208 Bug Fixed                     */   
/************************************************************************/    
    
CREATE PROC [dbo].[ispPnp_PackSKU]    
         @c_PickSlipNo   NVARCHAR(20),    
         @n_CartonNo       int,    
         @c_SKU            NVARCHAR(20),    
         @n_Qty            int,     
         @b_Success        int       OUTPUT,    
         @n_err            int       OUTPUT,    
         @c_errmsg       NVARCHAR(255) OUTPUT    
AS    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
DECLARE @n_count int /* next key */    
DECLARE @n_ncnt int    
DECLARE @n_starttcnt int /* Holds the current transaction count */    
DECLARE @n_continue int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */    
DECLARE @n_cnt int /* Variable to record if @@ROWCOUNT=0 after UPDATE */    
SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''    
    
DECLARE @c_StorerKey    NVARCHAR(15),    
        @c_LabelLine    NVARCHAR(5),    
        @c_OrderKey     NVARCHAR(10),    
        @n_QtyAllocated int,    
        @n_QtyPacked    int,     
        @c_dummy1       NVARCHAR(10),    
        @c_dummy2       NVARCHAR(10),    
        @c_LabelNo      NVARCHAR(20),    
        @c_loadkey      NVARCHAR(10)                  --CS01     
    
BEGIN TRANSACTION     
    
IF NOT EXISTS(SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)    
BEGIN    
   SELECT @n_continue = 3     
   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
   SELECT @c_errmsg='Invalid Pick Slip No. (ispPnp_PackSKU)'     
END    
    
IF @n_continue = 1 OR @n_continue = 2    
BEGIN    
   SELECT @c_StorerKey = StorerKey,     
          @c_OrderKey  = OrderKey,    
          @c_loadkey   = loadkey                  --CS01     
   FROM   PACKHEADER (NOLOCK)     
   WHERE  PickSlipNo = @c_PickSlipNo    
    
   IF dbo.fnc_RTrim(@c_StorerKey) IS NOT NULL AND dbo.fnc_RTrim(@c_StorerKey) <> '' AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND    
      dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) <> ''    
   BEGIN    
       SELECT @b_success = 0        
       EXECUTE nspg_GETSKU1        
             @c_StorerKey  = @c_StorerKey,        
             @c_sku      = @c_sku     OUTPUT,        
             @b_success    = @b_success OUTPUT,        
             @n_err        = @n_err     OUTPUT,        
             @c_errmsg     = @c_errmsg  OUTPUT,        
             @c_packkey    = @c_dummy1  OUTPUT,         
             @c_uom        = @c_dummy2  OUTPUT        
       IF NOT @b_success = 1        
       BEGIN        
            SELECT @n_continue = 3        
       END        
   END    
    
   -- Added By SHONG    
   -- SOS# 35108     
   -- NSC Taiwan Scan Pack Module Changes     
    
   DECLARE @cPrePackIndicator NVARCHAR(30),    
           @nPackQtyIndicator int     
    
   SELECT @cPrePackIndicator = ISNULL(PrePackIndicator, '0'),     
          @nPackQtyIndicator = PackQtyIndicator     
     FROM SKU (NOLOCK)     
   WHERE StorerKey = @c_StorerKey AND SKU = @c_SKU     
    
   IF @cPrePackIndicator = '2' AND @nPackQtyIndicator > 0     
   BEGIN    
      SET @n_Qty = @n_Qty * @nPackQtyIndicator    
   END    
    
 --IF ISNULL(@c_OrderKey,'') <> ''                         --CS01 Start    
 --BEGIN    
      
   IF NOT EXISTS(SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE OrderKey = @c_OrderKey AND StorerKey = @c_StorerKey AND    
         SKU = @c_SKU    
                  UNION ALL              --CS01 Satrt    
                  SELECT 1     
                  FROM packheader ph (NOLOCK)    
        JOIN orders o (NOLOCK) ON o.LoadKey=ph.LoadKey    
        JOIN pickdetail pdet (NOLOCK) ON pdet.OrderKey=o.OrderKey     
                  WHERE ph.loadkey = @c_loadkey     
         AND ph.StorerKey = @c_StorerKey     
         AND  SKU = @c_SKU)                     --CS01 End    
   BEGIN    
     SELECT @n_continue = 3     
     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': SKU NOT Exists in Order# ' + dbo.fnc_RTrim(@c_OrderKey) + '. (ispPnp_PackSKU)'     
   END      
      
    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      IF ISNULL(@c_OrderKey,'') <> ''            --CS01 Start    
      BEGIN    
    SELECT @n_QtyAllocated = SUM(ISNULL(Qty,0))     
    FROM   PICKDETAIL (NOLOCK)     
    WHERE OrderKey  =  @c_OrderKey    
    AND   StorerKey = @c_StorerKey     
    AND   SKU = @c_SKU    
      END    
      ELSE    
      BEGIN     
    SELECT @n_QtyAllocated = SUM(ISNULL(pdet.Qty,0))    
    FROM packheader ph (NOLOCK)    
    JOIN orders o (NOLOCK) ON o.LoadKey=ph.LoadKey    
    JOIN pickdetail pdet (NOLOCK) ON pdet.OrderKey=o.OrderKey     
    WHERE ph.loadkey = @c_loadkey     
     AND ph.StorerKey = @c_StorerKey     
     AND  SKU = @c_SKU    
  END --CS01 END    
    
      SELECT @n_QtyPacked = SUM(ISNULL(Qty,0))    
      FROM   PACKDETAIL (NOLOCK)     
      WHERE PickSlipNo = @c_PickSlipNo    
      AND   StorerKey = @c_StorerKey     
      AND   SKU = @c_SKU    
    
      IF @n_QtyPacked + @n_Qty > @n_QtyAllocated    
      BEGIN    
         SELECT @n_continue = 3     
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Packed Qty > Allocated Qty. (ispPnp_PackSKU)'     
      END     
   END       
END    
    
-- IF @n_continue = 1 OR @n_continue = 2    
-- BEGIN    
--    DELETE FROM PACKDETAIL     
--    WHERE PickSlipNo = @c_PickSlipNo    
--    AND   CartonNo   = @n_CartonNo    
--    AND   SKU = ''    
--    IF @@ERROR <> 0     
--    BEGIN    
--        SELECT @n_continue = 3     
--        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
--        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Pack Detail Failed. (ispPnp_PackSKU)'     
--    END    
--    SET ROWCOUNT 0     
-- END -- IF @n_continue = 1 OR @n_continue = 2    
  
--JSM-32208 Start  
IF @n_continue = 1 OR @n_continue = 2  
BEGIN  
   IF EXISTS(SELECT 1 FROM PACKDETAIL (NOLOCK)    
             WHERE PickSlipNo = @c_PickSlipNo    
             AND   CartonNo   = @n_CartonNo    
             AND   SKU = ''    
             AND   StorerKey = '')  
   BEGIN                                  
      IF EXISTS(SELECT 1 FROM PACKDETAIL (NOLOCK)    
                WHERE PickSlipNo = @c_PickSlipNo    
                AND   CartonNo   = @n_CartonNo    
                AND   SKU = @c_Sku    
                AND   StorerKey = @c_Storerkey)  
      BEGIN               
         DELETE FROM PackDetail   
         WHERE PickSlipNo = @c_PickSlipNo   
         AND CartonNo = @n_CartonNo  
         AND SKU = ''  
         AND Storerkey = ''  
           
         IF @@ERROR <> 0   
         BEGIN  
            SELECT @n_continue = 3   
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete PackDetail Failed. (ispPnp_PackSKU)'   
         END                 
      END           
   END            
END    
--JSM-32208 End    
  
IF @n_continue = 1 OR @n_continue = 2    
BEGIN    
   IF EXISTS(SELECT 1 FROM PACKDETAIL (NOLOCK)    
             WHERE PickSlipNo = @c_PickSlipNo    
             AND   CartonNo   = @n_CartonNo    
             AND   SKU = ''    
             AND   StorerKey = '')    
   BEGIN    
      UPDATE PACKDETAIL    
         SET Qty = Qty + @n_Qty,    
             SKU = @c_SKU,    
             StorerKey = @c_StorerKey     
      WHERE  PickSlipNo = @c_PickSlipNo    
      AND    CartonNo   = @n_CartonNo    
      AND    SKU = ''    
      AND    StorerKey = ''    
    
      SELECT @n_err = @@ERROR     
   END    
   ELSE IF NOT EXISTS(SELECT 1 FROM PACKDETAIL (NOLOCK)    
                 WHERE  PickSlipNo = @c_PickSlipNo    
                 AND    CartonNo   = @n_CartonNo    
                 AND    SKU = @c_SKU     
                 AND    StorerKey = @c_StorerKey)    
   BEGIN    
      -- Added By SHONG on 05-May-2005    
      -- SOS# 35108     
      -- NSC Taiwan Scan Pack Module Changes     
      SET @c_LabelNo = ''    
      SELECT @c_LabelLine = RIGHT('0000' + dbo.fnc_RTrim(CAST(ISNULL(CAST(MAX(LabelLine) as int), 0) + 1 as NVARCHAR(5))), 5),    
             @c_LabelNo = ISNULL( MAX(LabelNo), '')     
      FROM   PACKDETAIL (NOLOCK)    
      WHERE  PickSlipNo = @c_PickSlipNo     
      AND    CartonNo   = @n_CartonNo     
          
      IF dbo.fnc_RTrim(@c_LabelNo) IS NULL OR dbo.fnc_RTrim(@c_LabelNo) = ''    
      BEGIN    
         /*EXECUTE nspg_getkey    
            'PackNo' ,    
            10,    
            @c_LabelNo      Output ,    
            @b_success      = @b_success output,    
            @n_err          = @n_err output,    
            @c_errmsg       = @c_errmsg output,    
            @b_resultset    = 0,    
            @n_batch        = 1    
         */    
         --NJOW01    
        EXECUTE isp_GenUCCLabelNo_Std    
        @cPickslipNo = @c_PickSlipNo,        --(Wan01)  
  @nCartonNo   = @n_CartonNo,          --(CS02)    
        @cLabelNo    = @c_LabelNo   OUTPUT,  --(Wan01)    
        @b_success   = @b_success  OUTPUT,   --(Wan01)    
        @n_err       = @n_err      OUTPUT,   --(Wan01)    
        @c_errmsg    = @c_errmsg   OUTPUT    --(Wan01)    
                   
         IF @b_success <> 1    
         BEGIN    
            SELECT @n_continue = 3, @c_errmsg = 'isp_GenUCCLabelNo_Std' + dbo.fnc_RTrim(@c_errmsg)    
            GOTO EXIT_SP     
         END    
      END    
    
      INSERT INTO PackDetail(PickSlipNo, CartonNo, LabelLine, LabelNo, StorerKey, SKU, Qty, RefNo)    
      VALUES (@c_PickSlipNo, @n_CartonNo, @c_LabelLine, @c_LabelNo, @c_StorerKey, @c_SKU, @n_Qty, '')    
       
      SELECT @n_err = @@ERROR     
   END     
   ELSE    
   BEGIN    
      UPDATE PACKDETAIL    
         SET Qty = Qty + @n_Qty    
      WHERE  PickSlipNo = @c_PickSlipNo    
      AND    CartonNo   = @n_CartonNo    
      AND    SKU = @c_SKU    
      AND    StorerKey = @c_StorerKey    
    
      SELECT @n_err = @@ERROR     
   END     
    
   IF @n_err <> 0    
   BEGIN    
       SELECT @n_continue = 3     
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update Pack Detail Failed. (ispPnp_PackSKU)'     
   END    
END     
    
EXIT_SP:    
    
IF @n_continue=3  -- Error Occured - Process And Return    
BEGIN    
   SELECT @b_success = 0         
   IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt     
   BEGIN    
       ROLLBACK TRAN    
   END    
   ELSE BEGIN    
       WHILE @@TRANCOUNT > @n_starttcnt     
       BEGIN    
           COMMIT TRAN    
       END              
   END    
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPnp_PackSKU'    
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
   RETURN    
END    
ELSE     
BEGIN    
   SELECT @b_success = 1    
   WHILE @@TRANCOUNT > @n_starttcnt     
   BEGIN    
       COMMIT TRAN    
   END    
   RETURN    
END    
-- procedure 

GO