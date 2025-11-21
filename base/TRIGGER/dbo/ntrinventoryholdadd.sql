SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrInventoryHoldAdd                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: When records added into ITRN                              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 07-Sep-2006  MaryVong      Add in RDT compatible error messages      */
/* 09-Aug-2016  TLTING        Change Set ROWCOUNT 1 to Top 1            */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrInventoryHoldAdd]
ON  [dbo].[INVENTORYHOLD]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
	
   DECLARE
      @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
      ,         @n_err                int       -- Error number returned by stored procedure or this trigger
      ,         @n_err2 int              -- For Additional Error Detection
      ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
      ,         @n_continue int                 
      ,         @n_starttcnt int                -- Holds the current transaction count
      ,         @c_preprocess NVARCHAR(250)         -- preprocess
      ,         @c_pstprocess NVARCHAR(250)         -- post process
      ,         @n_cnt int                  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   /* #INCLUDE <TRADA1.SQL> */     
   /************************************************************************
   *	Add records in TransmitLog to track the QC HOLD		        *
   *************************************************************************/
   DECLARE @c_LOT    NVARCHAR(10),
         @c_LOC    NVARCHAR(10),
         @c_ID     NVARCHAR(18),
         @c_String NVARCHAR(255),
         @c_InventoryHoldKey NVARCHAR(10),
         @c_StorerKey        NVARCHAR(20),
         @c_Hold             NVARCHAR(1),
         @c_SKU              NVARCHAR(20),
         @n_Qty              float,
         @c_WorkOrderNo      NVARCHAR(18),
         @c_BatchNo          NVARCHAR(18)

   /* IDSV5 - Leo */
   Declare @c_primarykey NVARCHAR(10), @b_interface NVARCHAR(1), @c_transmitlogkey NVARCHAR(10), @c_authority NVARCHAR(1)
   Select @c_primarykey = ''
   While 1 = 1
   Begin
     -- Set rowcount 1
      Select TOP 1 @c_primarykey = InventoryHoldKey, 
      @c_hold = Hold, 
      @c_loc = Loc
      From INSERTED
      Where INSERTED.InventoryHoldKey > @c_primarykey
      Order by INSERTED.InventoryHoldKey
      if @@rowcount = 0
      Begin
         set rowcount 0
         break
      End
      Execute nspGetRight null,  -- Facility
         null,  -- Storer
         null,  -- Sku
         'INVENTORY HOLD - INTERFACE',      -- ConfigKey
         @b_success    output, 
         @c_authority  output, 
         @n_err        output, 
         @c_errmsg     output
      If @b_success <> 1
      Begin
         SELECT @n_continue = 3
         SELECT @n_err = 62476
         Select @c_errmsg = 'ntrInventoryHoldAdd: ' + dbo.fnc_RTrim(@c_errmsg)
         Break
      End
      Else 
      Begin
      If @c_authority = '1'
         Select @b_interface = '1'
      Else
         Select @b_interface = '0'
      End

      If @b_interface = '1'
      BEGIN
         If dbo.fnc_RTrim(@c_loc) is not null and @c_hold = '1' 
         Begin
   	      EXECUTE nspg_getkey
   	         'TransmitlogKey'
   	         ,10
   	         , @c_transmitlogkey OUTPUT
   	         , @b_success OUTPUT
   	         , @n_err OUTPUT
   	         , @c_errmsg OUTPUT
   	      IF NOT @b_success=1
   	      BEGIN
   	         SELECT @n_continue=3
   	         SELECT @n_err = 62477
   	         SELECT @c_errmsg = 'ntrInventoryHoldAdd: ' + dbo.fnc_RTrim(@c_errmsg)
   	      END
   	
   	      IF ( @n_continue = 1 or @n_continue = 2 ) 
   	      BEGIN
   	         INSERT TRANSMITLOG  (Transmitlogkey, tablename, key1, key2, key3,  transmitflag)
   	         VALUES  (@c_transmitlogkey, "InventoryHold", @c_primarykey, '', 'HOLD','0')
   	         SELECT @n_err= @@Error
   	         IF NOT @n_err=0
   	         BEGIN
   	            SELECT @n_continue=3 
   	            /* Trap SQL Server Error */
   	            Select @n_err = 62478 -- 99701
   	            Select @c_errmsg= 'NSQL'+CONVERT(char(5), @n_err)+':Insert Into TransmitLog Table (InventoryHold) Failed. (ntrInventoryHoldAdd)'+'('+'SQLSvr MESSAGE='+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))+')' 
   	         /* End Trap SQL Server Error */
               END
   	      END   
   	   End
	   End
    End
   /* IDSV5 - Leo */

   /* #INCLUDE <TRADA2.SQL> */
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
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrInventoryHoldAdd'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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