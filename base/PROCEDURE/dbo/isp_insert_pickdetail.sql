SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* SP: isp_Insert_PickDetail                                        	   */  
/* Creation Date:    19-Feb-2008                                        */  
/* Copyright: IDS                                                       */  
/* Written by:  TING TL                                                 */  
/*                                                                      */  
/* Purpose: Populate Order detail by pallet ID                   			*/  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: Power Builder Replenishment Module                        */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 28-Apr-2008  June				SOS101204 : Default original Orderline in */  
/*										OD.Userdefine02 for newly inserted line	*/
/* 24-Aug-2011  KHLim01		   Increase char length of StorerKey         */  
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/  

CREATE PROC  [dbo].[isp_Insert_PickDetail]  
@c_OrderKey         NVARCHAR(10)
,              @c_OrderLineNumber   NVARCHAR(5) 
,              @c_SKU   NVARCHAR(20)
,              @c_Lot   NVARCHAR(10)
,              @c_Loc   NVARCHAR(10)
,              @c_ID    NVARCHAR(18)
,              @n_Qty   int
,              @b_success          int OUTPUT  
,              @n_err              int OUTPUT    
,              @c_errmsg           NVARCHAR(255) OUTPUT   
AS  
BEGIN  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   -- SET ANSI_DEFAULTS OFF  

SET NOCOUNT ON  
DECLARE @n_count int /* next key */  
DECLARE @n_ncnt int  
DECLARE @n_starttcnt int /* Holds the current transaction count */  
DECLARE @n_continue int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */  
DECLARE @n_cnt int /* Variable to record if @@ROWCOUNT=0 after UPDATE */  
SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=""  



BEGIN TRANSACTION

IF ISNULL(@c_OrderKey, '') = '' OR ISNULL(@c_OrderLineNumber, '') = '' OR
   ISNULL(@c_SKU, '') = '' OR ISNULL(@c_Lot, '') = '' OR
   ISNULL(@c_Loc, '') = '' OR --ISNULL(@c_ID, '') = '' OR 
   ISNULL(@n_Qty, 0) = 0
BEGIN
      SELECT @n_continue = 3   
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Parameter. (isp_Insert_PickDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
END


   Declare @c_PickDetailKey NVARCHAR(18),
            @c_StorerKey    NVARCHAR(15),  -- KHLim01
            @c_PackKey      NVARCHAR(10),
            @c_UOM          NVARCHAR(10),
            @c_status       NVARCHAR(1),
            @n_Original_PickQty int,
            @n_Original_OpenQty int,
            @b_debug         NVARCHAR(1),
            @c_CartonGroup   NVARCHAR(10),
            @c_New_OrderLineNumber   NVARCHAR(5),
            @c_UOMType       NVARCHAR(1),
            @c_TariffKey      NVARCHAR(10),
            @c_Facility      NVARCHAR(5),
            @c_ExternOrderKey NVARCHAR(50)   --tlting_ext
  
  SELECT @b_debug = '1'
   SELECT @c_UOMType = '6'
   SELECT @c_status = 0
   SELECT @n_Original_PickQty = 0
   SELECT @c_StorerKey = ''
   SELECT @c_PackKey = ''
   SELECT @c_CartonGroup = ''

/*   SELECT   @c_StorerKey = ORDERDETAIL.StorerKey,
            @c_PackKey = SKU.Packkey,
            @c_CartonGroup = SKU.CartonGroup
   FROM ORDERDETAIL WITH (NOLOCK)
         JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.SKU = ORDERDETAIL.SKU)  
   WHERE OrderKey = @c_OrderKey
   AND   OrderLineNumber = @c_OrderLineNumber     
	SELECT @n_err = @@ERROR
	IF @n_err <> 0
	BEGIN
      SELECT @n_continue = 3   
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Read ORDERDETAIL. (isp_Insert_PickDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
	END
*/

   SELECT   @c_StorerKey = ORDERS.StorerKey, 
            @c_Facility =  ORDERS.Facility,
            @c_ExternOrderKey = Orders.ExternOrderKey
   FROM ORDERS WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey
	SELECT @n_err = @@ERROR
	IF @n_err <> 0
	BEGIN
      SELECT @n_continue = 3   
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Read ORDERS. (isp_Insert_PickDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
	END

   IF ISNULL(@c_StorerKey , '') = ''
   BEGIN
      SELECT @n_continue = 3   
      SELECT @n_err=61200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Read ORDERDETAIL. (isp_Insert_PickDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
   END

   SELECT       @c_TariffKey = TariffKey
   FROM TARIFFxFACILITY WITH (NOLOCK)
   WHERE FACILITY = @c_Facility
   AND STORERKEY  = @c_StorerKey
   AND SKU        = @c_Sku 

   IF @b_debug = '1'
   BEGIN
      SELECT '@c_StorerKey', @c_StorerKey
      SELECT '@c_Facility', @c_Facility
      SELECT '@c_ExternOrderKey', @c_ExternOrderKey
      SELECT '@c_TariffKey', @c_TariffKey
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- Update existsing order line
      IF Exists ( SELECT   ORDERDETAIL.SKU
                     FROM ORDERDETAIL WITH (NOLOCK)
                     WHERE OrderKey        = @c_OrderKey
                     AND   OrderLineNumber = @c_OrderLineNumber 
                     AND   ORDERDETAIL.SKU = @c_sku )
      BEGIN
   
         SELECT   @c_PackKey = SKU.Packkey,
                  @c_CartonGroup = SKU.CartonGroup,
                  @n_Original_OpenQty = OpenQty
         FROM ORDERDETAIL WITH (NOLOCK)
               JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.SKU = ORDERDETAIL.SKU)  
         WHERE OrderKey = @c_OrderKey
         AND   OrderLineNumber = @c_OrderLineNumber     
      	SELECT @n_err = @@ERROR
      	IF @n_err <> 0
      	BEGIN
            SELECT @n_continue = 3   
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Read ORDERDETAIL. (isp_Insert_PickDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      	END
      
         SELECT @c_New_OrderLineNumber = @c_OrderLineNumber

         SELECT @n_Original_PickQty = SUM(QTY)
         FROM PICKDETAIL WITH (NOLOCK)   
         WHERE OrderKey = @c_OrderKey 
         AND   OrderLineNumber = @c_OrderLineNumber     
      	SELECT @n_err = @@ERROR
      	IF @n_err <> 0
      	BEGIN
            SELECT @n_continue = 3   
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61300   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Read PICKDETAIL Fail. (isp_Insert_PickDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      	END
      
         IF @n_Original_PickQty IS NULL
            Select @n_Original_PickQty = 0
         
         IF @b_debug = '1'
         BEGIN
            SELECT '@c_PackKey', @c_PackKey
            SELECT '@c_CartonGroup', @c_CartonGroup
            SELECT '@n_Original_OpenQty', @n_Original_OpenQty
            SELECT '@n_Original_PickQty', @n_Original_PickQty
         END

         IF @n_Original_PickQty + @n_Qty >= ISNULL( ( SELECT SUM(OpenQty) 
                                          FROM ORDERDETAIL
                                          WHERE OrderKey = @c_OrderKey
                                          AND   OrderLineNumber = @c_OrderLineNumber ), 0)  
         BEGIN

            IF @b_debug = '1'
            BEGIN
                  SELECT 'Update Open QTY = @n_Original_PickQty + @n_Qty', @n_Original_PickQty + @n_Qty
            END 

               -- Change Orderdetail Open Qty
            UPDATE ORDERDETAIL
            SET OpenQty = @n_Original_PickQty + @n_Qty,
                UserDefine01 = CASE WHEN LEN(ISNULL(UserDefine01, '') ) = 0  THEN CASE WHEN @n_Original_OpenQty = 0 THEN '' ELSE CAST (@n_Original_OpenQty as char) END ELSE UserDefine01 END, -- IF UserDefine01 no value, update original open qty to UserDefine01
                ID = @c_ID 
            WHERE OrderKey = @c_OrderKey
            AND   OrderLineNumber = @c_OrderLineNumber     
         	SELECT @n_err = @@ERROR
         	IF @n_err <> 0
         	BEGIN
               SELECT @n_continue = 3   
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61400   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update ORDERDETAIL. (isp_Insert_PickDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         	END
         END


      END
      ELSE
      BEGIN
         -- INSERT AS New Order Line
         SELECT   @c_PackKey = SKU.Packkey,
                  @c_CartonGroup = SKU.CartonGroup,
                  @c_TariffKey = COALESCE(@c_TariffKey, SKU.TariffKey, 'XXXXXXXXXX' )
         FROM SKU WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
         AND SKU = @c_sku
         

         SELECT   @c_UOM = PackUOM3
         FROM PACK WITH (NOLOCK)
         WHERE  PACKKEY = @c_PackKey

         SELECT  @c_New_OrderLineNumber = MAX(ORDERDETAIL.OrderLineNumber)
         FROM ORDERDETAIL WITH (NOLOCK)
         WHERE OrderKey        = @c_OrderKey
         AND StorerKey       = @c_StorerKey

         SELECT @c_New_OrderLineNumber = @c_New_OrderLineNumber + 1
         SELECT @c_New_OrderLineNumber = RIGHT(REPLICATE ('0', 5) + dbo.fnc_RTrim(Convert(char(5), @c_New_OrderLineNumber ) ) , 5)

         IF @b_debug = '1'
         BEGIN
            SELECT 'NEW ORDER LINE'
            SELECT '@c_PackKey',@c_PackKey
            SELECT '@c_CartonGroup',@c_CartonGroup
            SELECT '@c_TariffKey',@c_TariffKey
            SELECT '@c_UOM',@c_UOM
            SELECT '@c_New_OrderLineNumber',@c_New_OrderLineNumber

         END 

         INSERT INTO ORDERDETAIL (
           OrderKey, OrderLineNumber, ExternOrderKey, Sku, StorerKey,  
           OpenQty, UOM, PackKey, Facility, TariffKey, ID,
			  Userdefine02 ) -- SOS101204
         VALUES  ( @c_OrderKey, @c_New_OrderLineNumber, @c_ExternOrderKey,  @c_Sku, @c_StorerKey,
                  @n_Qty, @c_UOM, @c_PackKey, @c_Facility, @c_TariffKey, @c_ID,
					   @c_OrderLineNumber) -- SOS101204
           
         	SELECT @n_err = @@ERROR
         	IF @n_err <> 0
         	BEGIN
               SELECT @n_continue = 3   
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61600   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT ORDERDETAIL Fail. (isp_Insert_PickDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            END

      END
   END   

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      EXECUTE nspg_GetKey
      'PICKDETAILKEY',
      10,
      	@c_pickdetailkey	OUTPUT,
      @b_success     	OUTPUT,
      @n_err         	OUTPUT,
      @c_errmsg      	OUTPUT
   
   
      IF @b_debug = '1'
      BEGIN
         SELECT 'INSERT PICKDETAIL ' + @c_pickdetailkey
      END

   	INSERT INTO PICKDETAIL
   	(PickDetailKey, --CaseID, 
      PickHeaderKey, OrderKey, OrderLineNumber, 
      Lot, Storerkey, Sku, --AltSku, 
      UOM, UOMQty, Qty, --QtyMoved, 
      Status, --DropID, 
      Loc, ID, PackKey, --UpdateSource, 
      CartonGroup --CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, 
      --WaveKey, EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, OptimizeCop, ShipFlag, PickSlipNo, 
      )
   	VALUES
   	(@c_pickdetailkey, '', @c_OrderKey, @c_New_OrderLineNumber, 
      @c_Lot, @c_StorerKey, @c_SKU,    
      @c_UOMType, 1, @n_Qty,
      @c_Status, 
      @c_Loc,    @c_ID,   @c_PackKey,
      @c_CartonGroup  )
   	SELECT @n_err = @@ERROR
   	IF @n_err <> 0
   	BEGIN
         SELECT @n_continue = 3   
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61700   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT PICKDETAIL Fail. (isp_Insert_PickDetail)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      END
   END   

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
     EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_Insert_PickDetail"  
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
     RETURN  
  END  
  ELSE BEGIN  
  SELECT @b_success = 1  
  WHILE @@TRANCOUNT > @n_starttcnt   
  BEGIN  
          COMMIT TRAN  
  END  
  RETURN  
END  
  
END -- Procedure   


GO