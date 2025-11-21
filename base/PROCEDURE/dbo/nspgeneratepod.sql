SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : nspGeneratePOD                                         */
/* Creation Date: 12-11-2008                                            */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose: Allow User to Generate POD when record not exist.           */
/*                                                                      */
/* Input Parameters: NONE                                               */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage: Alternative method for generate POD                           */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: MBOL Maintenance Screen - RCM Option                      */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications: Refer ntrMBOLHeaderUpdate                        */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */ 
/*                        store Orders (proj diana) (james02)           */ 
/* 28-Dec-2011  TLTING01  SOS231886 StorerConfig for X POD Actual       */
/*                        Develiry Date                                 */ 
/* 03-Jan-2018  Wan       WMS-3662 - Add Externloadkey to WMS POD module*/
/* 09-FEB-2018  CHEEMUN   INC0128904- LEFT JOIN Loadplan                */
/************************************************************************/
CREATE PROC    [dbo].[nspGeneratePOD]
   @c_MBOLKey        NVARCHAR(10), 
   @c_MBOLLineNumber NVARCHAR(5),
   @b_Success        int        OUTPUT,    
   @n_err            int        OUTPUT,    
   @c_errmsg         NVARCHAR(250)  OUTPUT    
AS
BEGIN 
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @n_continue   int,  
           @n_starttcnt  int,         -- Holds the current Transaction count
           @n_cnt        int,         -- Holds @@ROWCOUNT after certain operations
           @b_debug      int,         -- Debug On Or Off
           @n_error      int,
           @c_errmessage NVARCHAR(250)
  
   DECLARE @c_StorerKey  NVARCHAR(15),
           @c_facility   NVARCHAR(5),
           @c_authority  NVARCHAR(1)
                              
   SELECT @n_starttcnt=@@TRANCOUNT, 
          @n_continue=1, 
          @b_success=0,
          @n_err=0,
          @c_errmsg='', 
          @b_debug =0, 
          @n_error=0, 
          @c_errmessage=''
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- Generate POD Records Here...................
      SET ROWCOUNT 1
      SELECT @c_StorerKey = O.Storerkey, 
             @c_facility = O.Facility
      FROM   MBOLDetail M (NOLOCK)  
      JOIN   ORDERS O (NOLOCK) ON (O.OrderKey = M.OrderKey) 
      WHERE M.MBOLKey = @c_MBOLKey
      SET ROWCOUNT 0

      SELECT @b_success = 0
      EXECUTE nspGetRight @c_facility, -- facility
                @c_storerkey,         -- Storerkey 
                null,         -- Sku
                'POD',        -- Configkey
                @b_success    output,
                @c_authority  output, 
                @n_err        output,
                @c_errmessage output

      IF @b_debug = 1
      BEGIN
         SELECT '@b_success:', @b_success
         SELECT '@c_authority:', @c_authority
      END

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmessage = 'nspGeneratePOD' + dbo.fnc_RTrim(@c_errmessage)
      END
      ELSE IF @c_authority = '1'
      BEGIN 
         IF @b_debug = 1
         BEGIN
            SELECT 'Insert Details of MBOL into POD Table'
         END

         -- tlting01
         SET @c_authority = 0
         SELECT @b_success = 0
         EXECUTE nspGetRight @c_facility, -- facility
                            @c_storerkey, -- Storerkey -- SOS40271
                            null,         -- Sku
                            'PODXDeliverDate',        -- Configkey
                            @b_success    output,
                            @c_authority  output, 
                            @n_err        output,
                            @c_errmsg     output
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'nspGeneratePOD' + dbo.fnc_RTrim(@c_errmsg)
         END
         ELSE
         BEGIN
                  
            IF NOT EXISTS(SELECT 1 FROM POD (NOLOCK) WHERE Mbolkey = @c_mbolkey AND MBOLLineNumber = @c_MBOLLineNumber )
            BEGIN   
               INSERT INTO POD
                  (MBOLKey,         MBOLLineNumber, LoadKey, ExternLoadkey,   --(Wan01)
                   OrderKey,        BuyerPO,            ExternOrderKey, 
                   InvoiceNo,       status,             ActualDeliveryDate,
                   InvDespatchDate, poddef08,           Storerkey,   
                   SpecialHandling)
               SELECT  MBOLDetail.MBOLKey, 
                  MBOLDetail.MBOLLineNumber, 
                  MBOLDetail.LoadKey,
                  ISNULL(LP.ExternLoadkey, ''),                               --(Wan01)--INC0128904
                  ORDERS.OrderKey,
                  ORDERS.BuyerPO,
                  ORDERS.ExternOrderKey,
                  CASE 
                     WHEN wts.cnt = 1 THEN MBOLDetail.userdefine01
                     ELSE ORDERS.InvoiceNo
                  END, 
                  '0',
                  CASE WHEN @c_authority = '1' THEN NULL ELSE GETDATE() END, -- tlting01
                  GETDATE(),
                  MBOLDetail.its,
                  ORDERS.Storerkey,
                  ORDERS.SpecialHandling 
               FROM MBOLDetail WITH (NOLOCK)
               JOIN ORDERS WITH (NOLOCK) ON (MBOLDetail.OrderKey = ORDERS.OrderKey)
               LEFT JOIN LOADPLAN LP WITH (NOLOCK) ON (ORDERS.Loadkey = LP.Loadkey)--(Wan01)--INC0128904
               LEFT OUTER JOIN (SELECT storerkey, 1 as cnt
                                from storerconfig (nolock) 
                                where configkey = 'WTS-ITF' and svalue = '1') as wts
                  ON ORDERS.storerkey = wts.storerkey
               WHERE MBOLDetail.Mbolkey = @c_Mbolkey 
                 AND MBOLDetail.MbolLineNumber = @c_MBOLLineNumber
   
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmessage = CONVERT(CHAR(250),@n_error), @n_error=63801   
                  SELECT @c_errmessage='NSQL'+CONVERT(char(5),@n_error)+': Insert Failed On Table POD. (nspGeneratePOD)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmessage)) + ' ) '
               END
               ELSE
               BEGIN
                  SELECT @n_continue = 1
                  SELECT @c_errmessage = CONVERT(CHAR(250),@n_error), @n_error=63802   
                  SELECT @c_errmessage='NSQL'+CONVERT(char(5),@n_error)+': POD Successful Inserted. Mbolkey:' + dbo.fnc_RTrim(@c_Mbolkey) + ', MbolLineNumber:' + dbo.fnc_RTrim(@c_MBOLLineNumber) + ' (nspGeneratePOD)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmessage)) + ' ) '
               END -- @n_err <> 0
   
               IF @b_debug = 1
               BEGIN
                  SELECT * FROM POD WITH (NOLOCK)
                  WHERE Mbolkey = @c_Mbolkey 
                    AND MbolLineNumber = @c_MBOLLineNumber
               END
            END 
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmessage = CONVERT(CHAR(250),@n_error), @n_error=63803   
               SELECT @c_errmessage='NSQL'+CONVERT(char(5),@n_error)+': POD already exist. Mbolkey:' + dbo.fnc_RTrim(@c_Mbolkey) + ', MbolLineNumber:' + dbo.fnc_RTrim(@c_MBOLLineNumber) + ' (nspGeneratePOD)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmessage)) + ' ) '
            END -- IF NOT EXISTS POD
         END -- PODXDeliverDate
      END -- Authority = 1
      ELSE IF @c_authority = '0'
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmessage = CONVERT(CHAR(250),@n_error), @n_error=63804   
         SELECT @c_errmessage='NSQL'+CONVERT(char(5),@n_error)+': Not find StorerConfig. Storerkey:' + dbo.fnc_RTrim(@c_storerkey) + ', Facility:' + dbo.fnc_RTrim(@c_facility) + ', Configkey:POD (nspGeneratePOD)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmessage)) + ' ) '
      END
   END --@n_continue = 1 or @n_continue = 2
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      EXECUTE nspLogAlert
         @c_ModuleName   = "nspGeneratePOD",
         @c_AlertMessage = "Generate Of POD Ended Normally.",
         @n_Severity     = 0,
         @b_success       = @b_success OUTPUT,
         @n_err          = @n_err OUTPUT,
         @c_errmsg       = @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmessage = CONVERT(CHAR(250),@n_error), @n_error=63805   
         SELECT @c_errmessage='NSQL'+CONVERT(char(5),@n_error)+': Insert Failed On Table ALERT. (nspLogAlert)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmessage)) + ' ) '
      END
   END
   ELSE
   BEGIN
      IF @n_continue = 3
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspLogAlert
            @c_ModuleName   = "nspGeneratePOD",
            @c_AlertMessage = "Generate Of POD Ended Abnormally - Check This Log For Additional Messages.",
            @n_Severity     = 0,
            @b_success       = @b_success OUTPUT,
            @n_err          = @n_err OUTPUT,
            @c_errmsg       = @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmessage = CONVERT(CHAR(250),@n_error), @n_error=63806   
            SELECT @c_errmessage='NSQL'+CONVERT(char(5),@n_error)+': Insert Failed On Table ALERT. (nspLogAlert)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmessage)) + ' ) '
         END
      END
   END -- @n_continue = 1 or @n_continue = 2
        
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END -- @n_continue=3

      IF @b_debug = 1
      BEGIN
         SELECT '@n_err:', @n_err
         SELECT '@c_errmsg:', @c_errmsg
         SELECT '@n_error:', @n_error
         SELECT '@c_errmessage:', @c_errmessage
      END

      EXECUTE nsp_logerror @n_error, @c_errmessage, "nspGeneratePOD"
      RAISERROR (@c_errmessage, 16, 1) WITH SETERROR    -- SQL2012
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
END

GO