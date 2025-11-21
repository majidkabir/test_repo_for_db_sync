SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ScanOutOrder                                   */
/* Creation Date: 28.09.2015                                            */
/* Copyright: LFL                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Replace isp_ScanOutOrder Trigger, use Stored Proc           */
/*          to improve performance.                                     */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_ScanOutOrder]
       @c_OrderKey      NVARCHAR(10),
       @n_err           int = 0 OUTPUT,
       @c_errmsg        NVARCHAR(255) = '' OUTPUT,
       @c_Pickslipno    NVARCHAR(10) = '' OUTPUT,
       @c_ScanInOnly    NCHAR(1) = 'N'
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue    int
           ,@n_starttcnt   int
           ,@b_Success     int
           ,@c_StorerKey   NVARCHAR(15)
           ,@b_debug       int
           ,@c_LoadKey     NVARCHAR(10)
           ,@c_TicketType  NVARCHAR(18)
           ,@c_SoStatus    NVARCHAR(10)

   SET @b_debug = 0
   SET @n_continue=1
   SET @n_starttcnt=@@TRANCOUNT
   SET @c_TicketType = '3'
   SET @c_LoadKey = ''
   SET @c_PickSlipNo = ''
   SET @c_SoStatus = ''

   --WHILE @@TRANCOUNT > 0 
   --   COMMIT TRAN 
   
   SELECT @c_sostatus = SOStatus
   FROM ORDERS (NOLOCK) 
   WHERE Orderkey = @c_Orderkey
   
   IF ISNULL(@c_SOStatus,'') NOT IN('0','')
   BEGIN
      SELECT @n_Continue = 3 
	    SELECT @n_Err = 38000
	    SELECT @c_Errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Order''s SOStatus "'+ RTRIM(@c_SOStatus)  + '" Is Not Allowed To Scan Out. (isp_ScanOutOrder)'
      GOTO EXIT_SP 
   END
      
   SELECT @c_LoadKey = LoadKey, 
          @c_StorerKey = StorerKey 
   FROM   ORDERS WITH (NOLOCK)
   WHERE  OrderKey = @c_OrderKey
      
   SELECT @c_PickSlipNo = PickHeaderKey 
   FROM   PickHeader WITH (NOLOCK)
   WHERE  OrderKey = @c_OrderKey
   
   IF ISNULL(RTRIM(@c_PickSlipNo), '') = '' 
   BEGIN
      EXECUTE nspg_GetKey
      'PICKSLIP',
      9, 
      @c_PickSlipNo OUTPUT,
      @b_success OUTPUT,
      @n_err OUTPUT,
      @c_errmsg OUTPUT
      
      IF @b_success <> 1
      BEGIN
      	SELECT @n_continue = 3
      	GOTO EXIT_SP
      END
       
      SELECT @c_PickSlipNo = 'P' + @c_PickSlipNo
                      
      INSERT INTO PICKHEADER(PickHeaderKey, OrderKey, ExternOrderKey,
                             PickType, Zone, TrafficCop)
      VALUES ( @c_PickSlipNo, @c_OrderKey, @c_LoadKey, '0', @c_TicketType, '')    

	    SET @n_Err = @@ERROR
	                       
      IF @n_Err <> 0
      BEGIN
      	 SELECT @n_Continue = 3 
	       SELECT @n_Err = 38001
	       SELECT @c_Errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert PICKHEADER Failed. (isp_ScanOutOrder)'
         GOTO EXIT_SP 
      END           
   END
   
   IF NOT EXISTS (SELECT 1 FROM PickingInfo AS pi1 WITH (NOLOCK)
                  WHERE pi1.PickSlipNo = @c_PickSlipNo)
   BEGIN
      INSERT INTO PickingInfo( PickSlipNo, ScanInDate, PickerID, ScanOutDate)
      VALUES ( @c_PickSlipNo, GETDATE(), SUSER_SNAME(), NULL)
	    
	    SET @n_Err = @@ERROR
	                       
      IF @n_Err <> 0
      BEGIN
      	 SELECT @n_Continue = 3 
	       SELECT @n_Err = 38002
	       SELECT @c_Errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert PICKINGINFO Failed. (isp_ScanOutOrder)'
         GOTO EXIT_SP 
      END          
   END
                     
   IF (@n_continue = 1 or @n_continue=2) AND @c_ScanInOnly <> 'Y'
   BEGIN
      EXEC isp_ScanOutPickSlip
         @c_PickSlipNo = @c_PickSlipNo,
         @n_err = @n_err OUTPUT,
         @c_errmsg = @c_errmsg OUTPUT
   END

   EXIT_SP:
   -- To turn this on only when need to trace on the performance.
   -- insert into table, TraceInfo for tracing purpose.
   --IF @n_continue = 1 OR @n_continue = 2
   --BEGIN
      --WHILE @@TRANCOUNT < @n_starttcnt
         --BEGIN TRAN 
   --END
   
   /* #INCLUDE <TRMBOHA2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ScanOutOrder'
	       RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO