SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispTMSLogRCMSOnRtnTrigger                          */
/* Creation Date: 25-July-2006                                          */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose:  To update valid ORDERS/RECEIPT.RoutingTool = 'Y' and       */
/*           Call ispGenTMSLog to trigger records into the TMSLog       */
/*                                                                      */
/* Input Parameters:  @c_Key1         - OrderKey/ReceiptKey             */
/*                    @c_StorerKey    - Storerkey                       */
/*                    @c_InterfaceKey - StorerConfig/Tablename          */
/*                                                                      */
/* Output Parameters: @b_Success      - Success Flag  = 0               */
/*                    @n_err          - Error Code    = 0               */
/*                    @c_errmsg       - Error Message = ''              */
/*                                                                      */
/* Usage:  To trigger records for TMS outbound interfaces.              */
/*                                                                      */
/* Called By:  PB object - w_orders_maintenance                         */
/*                       - w_receipt_maintenance                        */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 25-Mar-2013  TLTING01  Update EditDate - trigger DM                  */
/* 16-Oct-2014  YTWan     SOS#322537 - [TW] New RequirementCreate TMS   */
/*                        Trigger on Wave Plan (Wan01)                  */
/************************************************************************/

CREATE PROC [dbo].[ispTMSLogRCMSOnRtnTrigger]  
            @c_Key1 NVARCHAR(10) , 
            @c_StorerKey NVARCHAR(18) , 
            @c_InterfaceKey NVARCHAR(30) , 
            @b_Success int OUTPUT , 
            @n_err int OUTPUT , 
            @c_errmsg NVARCHAR(225) OUTPUT 
         ,  @c_TransmitBatch  NVARCHAR(10) = ''    --(Wan01)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @b_debug int 
	SELECT  @b_debug = 0 
   DECLARE @n_continue int,
           @n_starttcnt int,  -- Holds the current transaction count
           @c_TMSLogFlag NVARCHAR(1)

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='' 
   SELECT @c_TMSLogFlag = 'N'
   /* #INCLUDE <SPIAD1.SQL> */

   SET @c_TransmitBatch = CASE WHEN @c_TransmitBatch IS NULL THEN '' ELSE @c_TransmitBatch END     --(Wan01)
 
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @b_debug = 1 
         SELECT '@c_InterfaceKey = N''' + @c_InterfaceKey + ''''

      -- For ORDERS - 'TMSOutOrdHDR' OR 'TMSOutOrdDTL'
      IF (dbo.fnc_RTrim(@c_InterfaceKey) = 'TMSOutOrdHDR') OR (dbo.fnc_RTrim(@c_InterfaceKey) = 'TMSOutOrdDTL') 
      BEGIN 
         IF EXISTS ( SELECT 1 FROM ORDERS (NOLOCK) 
                       JOIN StorerConfig (NOLOCK) ON ( StorerConfig.StorerKey = ORDERS.StorerKey )
                      WHERE ORDERS.OrderKey = @c_Key1 
                        AND ORDERS.StorerKey = @c_StorerKey 
                        AND dbo.fnc_RTrim(ConfigKey) = dbo.fnc_RTrim(@c_InterfaceKey) AND sValue = '1' ) 
         BEGIN 
            IF @b_debug = 1 
               SELECT 'Orders Updating..' 

            BEGIN TRAN
               -- Update ORDERS.RoutingTool = 'Y' 
               UPDATE ORDERS
                  SET RoutingTool = 'Y', 
                      Editdate = getdate(),   -- tlting01
                      TrafficCop = NULL
                 FROM ORDERS (NOLOCK)
                 JOIN StorerConfig (NOLOCK) ON ( StorerConfig.StorerKey = ORDERS.StorerKey AND 
                                                 dbo.fnc_RTrim(ConfigKey) = dbo.fnc_RTrim(@c_InterfaceKey) AND sValue = '1' ) 
                WHERE ORDERS.OrderKey = @c_Key1 

            IF @@ERROR = 0
            BEGIN 
               COMMIT TRAN
               SELECT @c_TMSLogFlag = 'Y'
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 68000
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Update records failed (ispTMSLogRCMSOnRtnTrigger)'  
            END	
         END 
      END -- For ORDERS - 'TMSOutOrdHDR' OR 'TMSOutOrdDTL'
      -- For RETURN - 'TMSOutRtnHDR' OR 'TMSOutRtnDTL'
      ELSE IF (dbo.fnc_RTrim(@c_InterfaceKey) = 'TMSOutRtnHDR') OR (dbo.fnc_RTrim(@c_InterfaceKey) = 'TMSOutRtnDTL') 
      BEGIN 
         IF EXISTS ( SELECT 1 FROM RECEIPT (NOLOCK) 
                       JOIN StorerConfig (NOLOCK) ON ( StorerConfig.StorerKey = RECEIPT.StorerKey AND 
                                                       dbo.fnc_RTrim(ConfigKey) = dbo.fnc_RTrim(@c_InterfaceKey) AND sValue = '1' ) 
                       JOIN CODELKUP (NOLOCK) ON ( RECEIPT.RecType = CODELKUP.Code AND 
                                                   CODELKUP.Listname = 'TMSReturn' )
                      WHERE RECEIPT.ReceiptKey = @c_Key1 
                        AND RECEIPT.StorerKey = @c_StorerKey 
                        AND RECEIPT.DocType = 'R' ) 
         BEGIN
            IF @b_debug = 1 
               SELECT 'Receipt Updating..' 

            BEGIN TRAN
               -- Update RECEIPT.RoutingTool = 'Y' 
               UPDATE RECEIPT
                  SET RoutingTool = 'Y',
                      Editdate = getdate(),   -- tlting01
                      TrafficCop = NULL
                 FROM RECEIPT (NOLOCK)
                 JOIN StorerConfig (NOLOCK) ON ( StorerConfig.StorerKey = RECEIPT.StorerKey AND 
                                                 dbo.fnc_RTrim(ConfigKey) = dbo.fnc_RTrim(@c_InterfaceKey) AND sValue = '1' ) 
                 JOIN CODELKUP (NOLOCK) ON ( RECEIPT.RecType = CODELKUP.Code AND 
                                             CODELKUP.Listname = 'TMSReturn' )
                WHERE RECEIPT.ReceiptKey = @c_Key1 
                  AND dbo.fnc_RTrim(RECEIPT.DocType) = 'R' 

            IF @@ERROR = 0
            BEGIN 
               COMMIT TRAN
               SELECT @c_TMSLogFlag = 'Y'
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 68001
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Update records failed (ispTMSLogRCMSOnRtnTrigger)'  
            END	
         END 
      END -- For RETURN - 'TMSOutRtnHDR' OR 'TMSOutRtnDTL'

      IF @@ERROR = 0
      BEGIN
         IF (@c_TMSLogFlag = 'Y')
         BEGIN
            SELECT @b_success = 0
            IF @b_debug = 1 
               SELECT 'TMSLog Inserting..' 

            -- Insert records into TMSLog table 
            EXEC ispGenTMSLog @c_InterfaceKey, @c_Key1, '', @c_StorerKey --,''   --(Wan01)
               , @c_TransmitBatch                                                --(Wan01)
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into TMSLog Failed (ispTMSLogRCMSOnRtnTrigger)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END
      END

      /* #INCLUDE <SPIAD2.SQL> */
      IF @n_continue=3  -- Error Occured - Process And Return
      BEGIN
         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END 
         ELSE 
         BEGIN 
            WHILE @@TRANCOUNT > @n_starttcnt
            BEGIN
               COMMIT TRAN
            END
         END
         EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ispTMSLogRCMSOnRtnTrigger'
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
   END -- IF @n_continue=1 OR @n_continue=2
END -- procedure

GO