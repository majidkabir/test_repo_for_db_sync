SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* 08-FEb-2018  SWT02         Adding Paramater Variable to Calling SP   */
/*                            - Channel                                 */
/************************************************************************/
CREATE TRIGGER ntrXDockDetailAdd
ON XDOCKDETAIL
FOR INSERT
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @b_debug INT
    SELECT @b_debug = 0
    IF @b_debug=2
    BEGIN
        DECLARE @profiler NVARCHAR(80)
        SELECT @profiler = "PROFILER,777,00,0,ntrXDockDetailAdd Trigger ,"+CONVERT(CHAR(12) ,GETDATE() ,114)
        PRINT @profiler
    END
    
    DECLARE @b_Success        INT -- Populated by calls to stored procedures - was the proc successful?
           ,@n_err            INT -- Error number returned by stored procedure or this trigger
           ,@n_err2           INT -- For Additional Error Detection
           ,@c_errmsg         NVARCHAR(250) -- Error message returned by stored procedure or this trigger
           ,@n_continue       INT
           ,@n_starttcnt      INT -- Holds the current transaction count
           ,@c_preprocess     NVARCHAR(250) -- preprocess
           ,@c_pstprocess     NVARCHAR(250) -- post process
           ,@n_cnt            INT
    
    SELECT @n_continue = 1
          ,@n_starttcnt = @@TRANCOUNT
    /* #INCLUDE <TRXDKDA1.SQL> */     
    IF @n_continue=1
       OR @n_continue=2
    BEGIN
        DECLARE @XDOCKPrimaryKey     NVARCHAR(15)
               ,@n_ItrnSysId         INT
               ,@c_StorerKey         NVARCHAR(15)
               ,@c_Sku               NVARCHAR(20)
               ,@c_Lot               NVARCHAR(10)
               ,@c_ToLoc             NVARCHAR(10)
               ,@c_ToID              NVARCHAR(18)
               ,@c_Status            NVARCHAR(10)
               ,@c_lottable01        NVARCHAR(18)
               ,@c_lottable02        NVARCHAR(18)
               ,@c_lottable03        NVARCHAR(18)
               ,@d_lottable04        DATETIME
               ,@d_lottable05        DATETIME
               ,@c_lottable06        NVARCHAR(30)  --CS01
               ,@c_lottable07        NVARCHAR(30)  --CS01
               ,@c_lottable08        NVARCHAR(30)  --CS01
               ,@c_lottable09        NVARCHAR(30)  --CS01
               ,@c_lottable10        NVARCHAR(30)  --CS01
               ,@c_lottable11        NVARCHAR(30)  --CS01
               ,@c_lottable12        NVARCHAR(30)  --CS01
               ,@d_lottable13        DATETIME   --CS01
               ,@d_lottable14        DATETIME   --CS01
               ,@d_lottable15        DATETIME   --CS01
               ,@n_casecnt           INT
               ,@n_innerpack         INT
               ,@n_Qty               INT
               ,@n_pallet            INT
               ,@f_cube              FLOAT
               ,@f_grosswgt          FLOAT
               ,@f_netwgt            FLOAT
               ,@f_otherunit1        FLOAT
               ,@f_otherunit2        FLOAT
               ,@c_SourceKey         NVARCHAR(15)
               ,@c_SourceType        NVARCHAR(30)
               ,@d_EffectiveDate     DATETIME
    END
    
    IF @n_continue=1
       OR @n_continue=2
    BEGIN
        IF @b_debug=2
        BEGIN
            SELECT @profiler = "PROFILER,777,02,0,ITRN Deposit Process                              ,"+CONVERT(CHAR(12) ,GETDATE() ,114)
            PRINT @profiler
        END
        
        SELECT @XDOCKPrimaryKey = " "
        WHILE (1=1)
        BEGIN
            SET ROWCOUNT 1
            SELECT @XDOCKPrimaryKey = XDOCKKey+XDOCKLineNumber
                  ,@n_ItrnSysId         = NULL
                  ,@c_StorerKey         = StorerKey
                  ,@c_Sku               = Sku
                  ,@c_Lot               = ""
                  ,@c_ToLoc             = ToLoc
                  ,@c_ToID              = ToID
                  ,@c_Status            = ConditionCode
                  ,@c_lottable01        = lottable01
                  ,@c_lottable02        = lottable02
                  ,@c_lottable03        = lottable03
                  ,@d_lottable04        = lottable04
                  ,@d_lottable05        = lottable05
                  ,@c_lottable06        = lottable06  --CS01
                  ,@c_lottable07        = lottable07  --CS01
                  ,@c_lottable08        = lottable08  --CS01
                  ,@c_lottable09        = lottable09  --CS01
                  ,@c_lottable10        = lottable10  --CS01
                  ,@c_lottable11        = lottable11  --CS01
                  ,@c_lottable12        = lottable12  --CS01
                  ,@d_lottable13        = lottable13  --CS01
                  ,@d_lottable14        = lottable14  --CS01
                  ,@d_lottable15        = lottable15  --CS01
                  ,@n_casecnt           = 0
                  ,@n_innerpack         = 0
                  ,@n_Qty               = ReceivedQty
                  ,@n_pallet            = 0
                  ,@f_cube              = Receivedcube
                  ,@f_grosswgt          = Receivedgrossweight
                  ,@f_netwgt            = Receivednetweight
                  ,@f_otherunit1        = 0
                  ,@f_otherunit2        = 0
                  ,@c_SourceKey         = XDOCKKey+XDOCKLineNumber
                  ,@c_SourceType        = "ntrXDockDetailAdd"
                  ,@d_EffectiveDate     = EffectiveDate
                  ,@b_Success           = 0
                  ,@n_err               = 0
                  ,@c_errmsg            = " "
            FROM   INSERTED
            WHERE  XDOCKKey+XDOCKLineNumber>@XDOCKPrimaryKey
                   AND ReceivedQty>0
            ORDER BY
                   XDOCKKey
                  ,XDOCKLineNumber
            
            IF @@ROWCOUNT=0
            BEGIN
                SET ROWCOUNT 0
                BREAK
            END
            
            SET ROWCOUNT 0
            EXECUTE nspItrnAddDeposit
                    @n_ItrnSysId=@n_ItrnSysId,
                 @c_StorerKey=@c_StorerKey,
                 @c_Sku=@c_Sku,
                 @c_Lot=@c_Lot,
                 @c_ToLoc=@c_ToLoc,
                 @c_ToID=@c_ToID,
                 @c_Status=@c_Status,
                 @c_lottable01=@c_lottable01,
                 @c_lottable02=@c_lottable02,
                 @c_lottable03=@c_lottable03,
                 @d_lottable04=@d_lottable04,
                 @d_lottable05=@d_lottable05,
                 @c_lottable06=@c_lottable06,   --CS01
                 @c_lottable07=@c_lottable07,   --CS01
                 @c_lottable08=@c_lottable08,   --CS01
                 @c_lottable09=@c_lottable09,   --CS01
                 @c_lottable10=@c_lottable10,   --CS01
                 @c_lottable11=@c_lottable11,   --CS01
                 @c_lottable12=@c_lottable12,   --CS01
                 @d_lottable13=@d_lottable13,   --CS01
                 @d_lottable14=@d_lottable14,   --CS01
                 @d_lottable15=@d_lottable15,   --CS01
                 @n_casecnt=@n_casecnt,
                 @n_innerpack=@n_innerpack,
                 @n_qty=@n_Qty,
                 @n_pallet=@n_pallet,
                 @f_cube=@f_cube,
                 @f_grosswgt=@f_grosswgt,
                 @f_netwgt=@f_netwgt,
                 @f_otherunit1=@f_otherunit1,
                 @f_otherunit2=@f_otherunit2,
                 @c_SourceKey=@c_SourceKey,
                 @c_SourceType=@c_SourceType,
                 @c_PackKey="",
                 @c_UOM="",
                 @b_UOMCalc=0,
                 @d_EffectiveDate=@d_EffectiveDate,
                 @c_itrnkey="",
                 @b_Success=@b_Success OUTPUT,
                 @n_err=@n_err OUTPUT,
                 @c_errmsg=@c_errmsg OUTPUT
            
            IF @b_success<>1
            BEGIN
                SELECT @n_continue = 3 
                BREAK
            END
        END
        SET ROWCOUNT 0
        IF @b_debug=2
        BEGIN
            SELECT @profiler = "PROFILER,777,02,9,ITRN Deposit Process                  ,"+CONVERT(CHAR(12) ,GETDATE() ,114)
            PRINT @profiler
        END
    END
    
    IF @n_continue=1
       OR @n_continue=2
    BEGIN
        IF @b_debug=2
        BEGIN
            SELECT @profiler = "PROFILER,777,02,0,ITRN Withdrawal Process                              ,"+CONVERT(CHAR(12) ,GETDATE() ,114)
            PRINT @profiler
        END
        
        SELECT @XDOCKPrimaryKey = " "
        WHILE (1=1)
        BEGIN
            SET ROWCOUNT 1
            SELECT @XDOCKPrimaryKey = XDOCKKey+XDOCKLineNumber
                  ,@n_ItrnSysId         = NULL
                  ,@c_StorerKey         = StorerKey
                  ,@c_Sku               = Sku
                  ,@c_Lot               = ""
                  ,@c_ToLoc             = ToLoc
                  ,@c_ToID              = ToID
                  ,@c_Status            = ConditionCode
                  ,@c_lottable01        = lottable01
                  ,@c_lottable02        = lottable02
                  ,@c_lottable03        = lottable03
                  ,@d_lottable04        = lottable04
                  ,@d_lottable05        = lottable05
                  ,@c_lottable06        = lottable06  --CS01
                  ,@c_lottable07        = lottable07  --CS01
                  ,@c_lottable08        = lottable08  --CS01
                  ,@c_lottable09        = lottable09  --CS01
                  ,@c_lottable10        = lottable10  --CS01
                  ,@c_lottable11        = lottable11  --CS01
                  ,@c_lottable12        = lottable12  --CS01
                  ,@d_lottable13        = lottable13  --CS01
                  ,@d_lottable14        = lottable14  --CS01
                  ,@d_lottable15        = lottable15  --CS01
                  ,@n_casecnt           = 0
                  ,@n_innerpack         = 0
                  ,@n_Qty               = ShippedQty
                  ,@n_pallet            = 0
                  ,@f_cube              = Shippedcube
                  ,@f_grosswgt          = Shippedgrossweight
                  ,@f_netwgt            = Shippednetweight
                  ,@f_otherunit1        = 0
                  ,@f_otherunit2        = 0
                  ,@c_SourceKey         = XDOCKKey+XDOCKLineNumber
                  ,@c_SourceType        = "ntrXDockDetailAdd"
                  ,@d_EffectiveDate     = EffectiveDate
                  ,@b_Success           = 0
                  ,@n_err               = 0
                  ,@c_errmsg            = " "
            FROM   INSERTED
            WHERE  XDOCKKey+XDOCKLineNumber>@XDOCKPrimaryKey
                   AND ShippedQty>0
            ORDER BY
                   XDOCKKey
                  ,XDOCKLineNumber
            
            IF @@ROWCOUNT=0
            BEGIN
                SET ROWCOUNT 0
                BREAK
            END
            
            SET ROWCOUNT 0
            EXECUTE nspItrnAddWithdrawal
                    @n_ItrnSysId=@n_ItrnSysId,
                 @c_StorerKey=@c_StorerKey,
                 @c_Sku=@c_Sku,
                 @c_Lot=@c_Lot,
                 @c_ToLoc=@c_ToLoc,
                 @c_ToID=@c_ToID,
                 @c_Status=@c_Status,
                 @c_lottable01=@c_lottable01,
                 @c_lottable02=@c_lottable02,
                 @c_lottable03=@c_lottable03,
                 @d_lottable04=@d_lottable04,
                 @d_lottable05=@d_lottable05,
                 @c_lottable06=@c_lottable06,   --CS01
                 @c_lottable07=@c_lottable07,   --CS01
                 @c_lottable08=@c_lottable08,   --CS01
                 @c_lottable09=@c_lottable09,   --CS01
                 @c_lottable10=@c_lottable10,   --CS01
                 @c_lottable11=@c_lottable11,   --CS01
                 @c_lottable12=@c_lottable12,   --CS01
                 @d_lottable13=@d_lottable13,   --CS01
                 @d_lottable14=@d_lottable14,   --CS01
                 @d_lottable15=@d_lottable15,   --CS01
                 @n_casecnt=@n_casecnt,
                 @n_innerpack=@n_innerpack,
                 @n_qty=@n_Qty,
                 @n_pallet=@n_pallet,
                 @f_cube=@f_cube,
                 @f_grosswgt=@f_grosswgt,
                 @f_netwgt=@f_netwgt,
                 @f_otherunit1=@f_otherunit1,
                 @f_otherunit2=@f_otherunit2,
                 @c_SourceKey=@c_SourceKey,
                 @c_SourceType=@c_SourceType,
                 @c_PackKey="",
                 @c_UOM="",
                 @b_UOMCalc=0,
                 @d_EffectiveDate=@d_EffectiveDate,
                 @c_itrnkey="",
                 @b_Success=@b_Success OUTPUT,
                 @n_err=@n_err OUTPUT,
                 @c_errmsg=@c_errmsg OUTPUT
            
            IF @b_success<>1
            BEGIN
                SELECT @n_continue = 3 
                BREAK
            END
        END
        SET ROWCOUNT 0
        IF @b_debug=2
        BEGIN
            SELECT @profiler = "PROFILER,777,02,9,ITRN Withdrawal Process                              ,"+CONVERT(CHAR(12) ,GETDATE() ,114)
            PRINT @profiler
        END
    END
    
    IF @n_continue=1
       OR @n_continue=2
    BEGIN
        IF @b_debug=2
        BEGIN
            SELECT @profiler = "PROFILER,777,03,0,XDOCK Update                                    ,"+CONVERT(CHAR(12) ,GETDATE() ,114)
            PRINT @profiler
        END
        
        DECLARE @n_insertedcount INT
        SELECT @n_insertedcount = (
                   SELECT COUNT(*)
                   FROM   INSERTED
               )
        
        IF @n_insertedcount=1
        BEGIN
            UPDATE XDOCK
            SET    XDOCK.ExpectedTotalQty = XDOCK.ExpectedTotalQty+INSERTED.ExpectedQty
                  ,XDOCK.ReceivedTotalQty = XDOCK.ReceivedTotalQty+INSERTED.ReceivedQty
                  ,XDOCK.ShippedTotalQty = XDOCK.ShippedTotalQty+INSERTED.ShippedQty
                  ,XDOCK.ExpectedTotalGrossWgt = XDOCK.ExpectedTotalGrossWgt+INSERTED.ExpectedGrossWeight
                  ,XDOCK.ReceivedTotalGrossWgt = XDOCK.ReceivedTotalGrossWgt+INSERTED.ReceivedGrossWeight
                  ,XDOCK.ShippedTotalGrossWgt = XDOCK.ShippedTotalGrossWgt+INSERTED.ShippedGrossWeight
                  ,XDOCK.ExpectedTotalNetWgt = XDOCK.ExpectedTotalNetWgt+INSERTED.ExpectedNetWeight
                  ,XDOCK.ReceivedTotalNetWgt = XDOCK.ReceivedTotalNetWgt+INSERTED.ReceivedNetWeight
                  ,XDOCK.ShippedTotalNetWgt = XDOCK.ShippedTotalNetWgt+INSERTED.ShippedNetWeight
                  ,XDOCK.ExpectedTotalCube = XDOCK.ExpectedTotalCube+INSERTED.ExpectedCube
                  ,XDOCK.ReceivedTotalCube = XDOCK.ReceivedTotalCube+INSERTED.ReceivedCube
                  ,XDOCK.ShippedTotalCube = XDOCK.ShippedTotalCube+INSERTED.ShippedCube
            FROM   XDOCK
                  ,INSERTED
            WHERE  XDOCK.XDOCKKey = INSERTED.XDOCKKey
        END
        ELSE
        BEGIN
            UPDATE XDOCK
            SET    XDOCK.ReceivedTotalQty = (
                       SELECT SUM(ReceivedQty)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ExpectedTotalQty = (
                       SELECT SUM(ExpectedQty)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ShippedTotalQty = (
                       SELECT SUM(ShippedQty)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ReceivedTotalGrossWgt = (
                       SELECT SUM(ReceivedGrossWeight)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ExpectedTotalGrossWgt = (
                       SELECT SUM(ExpectedGrossWeight)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ShippedTotalGrossWgt = (
                       SELECT SUM(ShippedGrossWeight)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ReceivedTotalNetWgt = (
                       SELECT SUM(ReceivedNetWeight)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ExpectedTotalNetWgt = (
                       SELECT SUM(ExpectedNetWeight)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ShippedTotalNetWgt = (
                       SELECT SUM(ShippedNetWeight)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ReceivedTotalCube = (
                       SELECT SUM(ReceivedCube)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ExpectedTotalCube = (
                       SELECT SUM(ExpectedCube)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
                  ,XDOCK.ShippedTotalCube = (
                       SELECT SUM(ShippedCube)
                       FROM   XDOCKDETAIL
                       WHERE  XDOCKDETAIL.XDOCKkey = XDOCK.XDOCKkey
                   )
            FROM   XDOCK
                  ,INSERTED
            WHERE  XDOCK.XDOCKkey IN (SELECT DISTINCT XDOCKkey
                                      FROM   INSERTED)
                   AND XDOCK.XDOCKkey = INSERTED.XDOCKkey
        END
        SELECT @n_err = @@ERROR
              ,@n_cnt = @@ROWCOUNT
        
        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 77704 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                   ": Update failed on table XDOCKDETAIL. (ntrXDockDetailAdd)"+" ( "+" SQLSvr MESSAGE="+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) 
                  +" ) "
        END
        ELSE 
        IF @n_cnt=0
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 77705 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                   ": Zero rows affected updating table XDOCK. (ntrXDockDetailAdd)"+" ( "+" SQLSvr MESSAGE="+
                   dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))+" ) "
        END
        
        IF @b_debug=2
        BEGIN
            SELECT @profiler = "PROFILER,777,03,9,XDOCK Update                                    ,"+CONVERT(CHAR(12) ,GETDATE() ,114)
            PRINT @profiler
        END
    END
    /* #INCLUDE <TRXDKDA2.SQL> */
    IF @n_continue=3 -- Error Occured - Process And Return
    BEGIN
        IF @@TRANCOUNT=1
           AND @@TRANCOUNT>=@n_starttcnt
        BEGIN
            ROLLBACK TRAN
        END
        ELSE
        BEGIN
            WHILE @@TRANCOUNT>@n_starttcnt
            BEGIN
                COMMIT TRAN
            END
        END
        EXECUTE nsp_logerror @n_err,
             @c_errmsg,
             "ntrXDockDetailAdd"
        
        RAISERROR (@c_errmsg ,16 ,1) WITH SETERROR -- SQL2012
        IF @b_debug=2
        BEGIN
            SELECT @profiler = "PROFILER,777,00,9,ntrXDockDetailAdd Tigger                       ,"+CONVERT(CHAR(12) ,GETDATE() ,114)
            PRINT @profiler
        END
        
        RETURN
    END
    ELSE
    BEGIN
        WHILE @@TRANCOUNT>@n_starttcnt
        BEGIN
            COMMIT TRAN
        END
        IF @b_debug=2
        BEGIN
            SELECT @profiler = "PROFILER,777,00,9,ntrXDockDetailAdd Trigger                       ,"+CONVERT(CHAR(12) ,GETDATE() ,114)
            PRINT @profiler
        END
        
        RETURN
    END
END

GO