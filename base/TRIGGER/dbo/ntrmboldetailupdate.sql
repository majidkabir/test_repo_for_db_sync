SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Store Procedure:  ntrMBOLDetailUpdate                                    */
/* Creation Date:                                                           */
/* Copyright: IDS                                                           */
/* Written by:                                                              */
/*                                                                          */
/* Purpose:  MBOLDetailUpdate Trigger                                       */
/*                                                                          */
/* Input Parameters:                                                        */
/*                                                                          */
/* Output Parameters:  None                                                 */
/*                                                                          */
/* Return Status:  None                                                     */
/*                                                                          */
/* Usage:                                                                   */
/*                                                                          */
/* Local Variables:                                                         */
/*                                                                          */
/* Called By:                                                               */
/*                                                                          */
/* PVCS Version: 2.1                                                        */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author    Ver.  Purposes                                    */
/* 17-Mar-2009  TLTING    1.1   Change user_name() to SUSER_SNAME()         */
/* 05-May-2010  NJOW01    1.2   168916 - update total carton to mbol        */
/*                              depend on mbol.userdefine09                 */
/* 25-May-2011  Ung       1.3   SOS216105 Configurable SP to calc           */
/*                              carton, cube and weight                     */
/* 25-May-2011  Ung       1.4   SOS216105 Configurable SP to calc           */
/*                              carton, cube and weight                     */
/* 09-Apr-2012  TLTING    1.5   Re position Rowcount 0 Return               */
/* 06-APR-2012  YTWan     1.6   SOS#238876:ReplaceUSAMBOL.Calculate         */
/*                              NoofCartonPacked. (Wan01)                   */  
/* 23-Apr-2012  NJOW02    1.7   241032-Calculation by coefficient           */
/* 23 May 2012  TLTING02  1.8   DM integrity - add update editdate B4       */
/*                              TrafficCop for status < '9'                 */ 
/* 28-Oct-2013  TLTING    1.9   Review Editdate column update               */ 
/* 08-Dec-2015  NJOW03    2.0   358632-Skip auto sp calculate for Ecom order*/
/* 28-JUL-2017  Wan02     2.1   WMS-1916 - WMS Storerconfig for Copy        */
/*                              totalcarton to ctncnt1 in mboldetail        */
/****************************************************************************/
CREATE TRIGGER [dbo].[ntrMBOLDetailUpdate] 
ON [dbo].[MBOLDETAIL] FOR UPDATE AS
BEGIN
 
 IF @@ROWCOUNT = 0
 BEGIN
   RETURN
 END 
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
 ,         @c_authority NVARCHAR(1) -- Add by June for IDSV5 28.Jun.02
 ,         @n_ttlcnts      INT                                                                     --(Wan01)
 ,         @c_mbolkey      NVARCHAR(10)
 ,         @c_short     NVARCHAR(10) --NJOW03                                                               --(Wan01)

 SET @n_ttlcnts = 0                                                                                --(Wan01)
 SET @c_mbolkey = ''                                                                               --(Wan01)
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

 IF UPDATE(ArchiveCop)
 BEGIN
    SELECT @n_continue = 4 
 END
 
 -- tlting01
 IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate) 
 BEGIN
    UPDATE MBOLDetail with (ROWLOCK)
    SET EditDate = GETDATE(),
        EditWho = SUSER_SNAME(),
        TrafficCop = NULL
    FROM MBOLDetail, INSERTED
    WHERE MBOLDetail.MBOLKey = INSERTED.MBOLKey
    AND MBOLDetail.MBOLLineNumber = INSERTED.MBOLLineNumber
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table MBOLDetail. (ntrMBOLDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
 
 IF UPDATE(TrafficCop)
 BEGIN
    SELECT @n_continue = 4 
 END

 /* #INCLUDE <TRMBODU1.SQL> */     
 /*
 IF @n_continue=1 or @n_continue=2
 BEGIN
 IF EXISTS (SELECT * FROM MBOL, INSERTED
 WHERE MBOL.MBOLKey = INSERTED.MBOLKey
 AND MBOL.Status = "9")
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err=73100
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": MBOL.Status = 'SHIPPED'. UPDATE rejected. (ntrMBOLDetailUpdate)"
 END
 END
 */
   --(Wan02) - START
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED d
                 JOIN ORDERS O WITH (NOLOCK) ON (D.OrderKey = O.OrderKey)
                 JOIN storerconfig s WITH (NOLOCK) ON (O.storerkey = s.storerkey)
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'MBOLDetailTrigger_SP')
      BEGIN
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

          SELECT *
          INTO #INSERTED
          FROM INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED

          SELECT *
          INTO #DELETED
          FROM DELETED

         EXECUTE dbo.isp_MBOLDetailTrigger_Wrapper
                   'UPDATE'  --@c_Action
                 , @b_Success  OUTPUT
                 , @n_Err      OUTPUT
                 , @c_ErrMsg   OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
                  ,@c_errmsg = 'ntrMBOLDetailUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END

         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END
   --(Wan02) - END

 -- for ACSIE (IDSPH)
 -- WALLY 8.may.2001
 -- mandatory fields based on invoice status
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
   -- Added for IDSV5 by June 28.Jun.02, (extract from IDSPH) *** Start
   SELECT @b_success = 0
   Execute nspGetRight null,   -- facility
             null,    -- Storerkey
             null,            -- Sku
             'ACSIE',         -- Configkey
             @b_success      output,
             @c_authority   output, 
             @n_err         output,
             @c_errmsg      output
   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrMBOLDetailUpdate' + dbo.fnc_RTrim(@c_errmsg)
   END
   ELSE IF @c_authority = '1'
   BEGIN    -- Added for IDSV5 by June 28.Jun.02, (extract from IDSPH) *** End
       DECLARE @c_invoicestatus NVARCHAR(10),
          @d_deliverydate datetime,
          @c_pcm NVARCHAR(12),
          @c_reason NVARCHAR(60)
       SELECT @c_invoicestatus = INSERTED.invoicestatus,
          @d_deliverydate = INSERTED.deliverydate,
          @c_pcm = INSERTED.pcmnum,
          @c_reason = INSERTED.externreason
       FROM INSERTED INNER JOIN MBOLDETAIL
         ON (INSERTED.mbolkey = MBOLDETAIL.mbolkey AND INSERTED.mbollinenumber = MBOLDETAIL.mbollinenumber)
       IF @c_invoicestatus = 'D' AND @d_deliverydate IS NULL
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72611   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+" : ACTUAL DELIVERY DATE REQUIRED..."
       END
       ELSE IF @c_invoicestatus = 'J' AND (@c_pcm IS NULL OR @c_pcm = '') AND (@c_reason IS NULL OR @c_reason = '')
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72611   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+" : PCM NUMBER and REASON CODE REQUIRED..."
       END   
   END
 END

--SOS#168916  NJOW01
 IF (@n_continue = 1 OR @n_continue = 2) AND UPDATE(totalcartons)
 BEGIN
      IF EXISTS(SELECT 1
              FROM   INSERTED I 
              JOIN   Orders O WITH (NOLOCK) ON (O.OrderKey = I.OrderKey) 
              JOIN   StorerConfig S WITH (NOLOCK) ON (S.StorerKey = O.StorerKey)
              WHERE  S.sValue NOT IN ('0','') 
              AND    S.Configkey = 'MBOLDEFAULT')
    BEGIN
          UPDATE MBOL WITH (ROWLOCK)
           SET noofidscarton = CASE WHEN MBOL.userdefine09 = 'IDS' THEN
                                 noofidscarton - (SELECT SUM(DELETED.totalcartons) FROM DELETED WHERE DELETED.Mbolkey = MBOL.Mbolkey)
                                 + (SELECT SUM(INSERTED.totalcartons) FROM INSERTED WHERE INSERTED.Mbolkey = MBOL.Mbolkey)
                            ELSE 0 END,
              noofcustomercarton = CASE WHEN MBOL.userdefine09 = 'CUSTOMER' THEN
                                       noofcustomercarton - (SELECT SUM(DELETED.totalcartons) FROM DELETED WHERE DELETED.Mbolkey = MBOL.Mbolkey)
                                       + (SELECT SUM(INSERTED.totalcartons) FROM INSERTED WHERE INSERTED.Mbolkey = MBOL.Mbolkey)
                                   ELSE 0 END,
              TrafficCop = NULL,
              EditDate = GETDATE(),       --tlting
              EditWho = SUSER_SNAME()
           FROM MBOL 
           WHERE MBOL.Mbolkey IN (SELECT DISTINCT Mbolkey FROM DELETED)
        SELECT @n_err = @@ERROR
        IF @n_err <> 0
        BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73112   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table MBOL. (ntrMBOLDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
        END          
    END
   --(Wan01) - START

   IF EXISTS ( SELECT 1
               FROM INSERTED
               JOIN DELETED ON (INSERTED.MBOLKey = DELETED.MBolkey) AND (INSERTED.MBolLineNumber = DELETED.MBolLineNumber)
               WHERE INSERTED.TotalCartons <> DELETED.TotalCartons )
   BEGIN

      SELECT @c_MBolkey = MBolkey
      FROM INSERTED

      SELECT @n_ttlcnts = SUM(TotalCartons)
      FROM MBOLDETAIL WITH (NOLOCK)  
      WHERE MBolkey = @c_MBOLKey
          
      UPDATE MBOL WITH (ROWLOCK)
      SET NoofCartonPacked = @n_ttlcnts
       , EditWho = SUSER_NAME() 
       , EditDate = GETDATE()   
       , Trafficcop = NULL
      WHERE Mbolkey = @c_MBOLKey
      
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err=72612
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table MBOL. (ntrMBOLDetailAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   --(Wan01) - END
 END 
 
-- SOS216105. Configurable SP to calc carton, cube and weight
IF (@n_continue = 1 OR @n_continue = 2) AND (
   UPDATE( TotalCartons) OR 
   UPDATE( CtnCnt1) OR 
   UPDATE( CtnCnt2) OR 
   UPDATE( CtnCnt3) OR 
   UPDATE( CtnCnt4) OR 
   UPDATE( CtnCnt5))
BEGIN
   DECLARE @cSValue     NVARCHAR( 10)
   DECLARE @cSP_Cube    SYSNAME
   DECLARE @cSP_Weight  SYSNAME
   DECLARE @cSQL        NVARCHAR( 400)
   DECLARE @cParam      NVARCHAR( 400)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cPickSlipNo NVARCHAR( 10)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cMBOLKey    NVARCHAR( 10)
   DECLARE @cMBOLLineNumber NVARCHAR( 5)
   DECLARE @nCtnCnt1     INT
   DECLARE @nCtnCnt2     INT
   DECLARE @nCtnCnt3     INT
   DECLARE @nCtnCnt4     INT
   DECLARE @nCtnCnt5     INT
   DECLARE @nTotalCube   FLOAT
   DECLARE @nTotalWeight FLOAT
   DECLARE @nCurrentTotalCube   FLOAT
   DECLARE @nCurrentTotalWeight FLOAT
   DECLARE @n_Coefficient_carton float,  --NJOW02
           @n_Coefficient_cube   float,  --NJOW02
           @n_Coefficient_weight float   --NJOW02


   DECLARE curMD CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT MBOLKey, MBOLLineNumber, OrderKey, Cube, Weight, CtnCnt1, CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5
      FROM INSERTED
   OPEN curMD
   FETCH NEXT FROM curMD INTO @cMBOLKey, @cMBOLLineNumber, @cOrderKey, @nCurrentTotalCube, @nCurrentTotalWeight, @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Determine if discrete pick list
      IF EXISTS( SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
      BEGIN
         SELECT @cStorerKey = StorerKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
         
         -- Get pick or pack formula
         IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
            SELECT @cSValue = SValue FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ConfigKey = 'CMSPackingFormula'
         ELSE
            SELECT @cSValue = SValue FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ConfigKey = 'CMSNoPackingFormula'
         
         IF @cSValue <> '' AND @cSValue IS NOT NULL
         BEGIN
            -- Get customize stored procedure
            SELECT 
               @cSP_Cube = Notes, 
               @cSP_Weight = Notes2,
               @n_Coefficient_carton = CASE WHEN ISNUMERIC(UDF01) = 1 THEN
                                            CONVERT(float,UDF01) ELSE 1 END,  --NJOW02
               @n_Coefficient_cube = CASE WHEN ISNUMERIC(UDF02) = 1 THEN
                                            CONVERT(float,UDF02) ELSE 1 END,  --NJOW02
               @n_Coefficient_weight = CASE WHEN ISNUMERIC(UDF03) = 1 THEN
                                            CONVERT(float,UDF03) ELSE 1 END,  --NJOW02
               @c_Short = Short --NJOW03
            FROM CodeLkup WITH (NOLOCK)
            WHERE ListName = 'CMSStrateg'
               AND Code = @cSValue
            
            -- Run cube SP
            IF OBJECT_ID( @cSP_Cube, 'P') IS NOT NULL 
               AND NOT EXISTS (SELECT 1 FROM ORDERS (NOLOCK)  --NJOW03
                               WHERE Orderkey = @cOrderkey
                               AND Doctype = 'E'
                               AND @c_short IN ('1','12','21'))  -- 1=CUBE 2=WEIGHT
            BEGIN
               SET @cSQL = 'EXEC ' + @cSP_Cube + ' @cPickSlipNo, @cOrderKey, @nTotalCube OUTPUT, @nCurrentTotalCube, @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5'
               SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), @nTotalCube FLOAT OUTPUT, @nCurrentTotalCube FLOAT , @nCtnCnt1 INT, @nCtnCnt2 INT, @nCtnCnt3 INT, @nCtnCnt4 INT, @nCtnCnt5 INT'
               EXEC sp_executesql @cSQL, @cParam, @cPickSlipNo, @cOrderKey, @nTotalCube OUTPUT, @nCurrentTotalCube, @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73112
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table MBOL. (ntrMBOLDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  BREAK
               END 

               --NJOW02
               SET @nTotalCube = ISNULL(@nTotalCube,0) * @n_Coefficient_cube             
               
               UPDATE MBOLDetail SET Cube = @nTotalCube WHERE MBOLKey = @cMBOLKey AND MBOLLineNumber = @cMBOLLineNumber
               SET @n_err = @@ERROR                  
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73112
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table MBOL. (ntrMBOLDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  BREAK
               END 
            END

            -- Run weight SP
            IF OBJECT_ID( @cSP_Weight, 'P') IS NOT NULL 
               AND NOT EXISTS (SELECT 1 FROM ORDERS (NOLOCK)  --NJOW03
                               WHERE Orderkey = @cOrderkey
                               AND Doctype = 'E'
                               AND @c_short IN ('2','12','21'))  -- 1=CUBE 2=WEIGHT  
            BEGIN
               SET @cSQL = 'EXEC ' + @cSP_Weight + ' @cPickSlipNo, @cOrderKey, @nTotalWeight OUTPUT, @nCurrentTotalWeight'
               SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), @nTotalWeight FLOAT OUTPUT, @nCurrentTotalWeight FLOAT'
               EXEC sp_executesql @cSQL, @cParam, @cPickSlipNo, @cOrderKey, @nTotalWeight OUTPUT, @nCurrentTotalWeight
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73112
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table MBOL. (ntrMBOLDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  BREAK
               END 

               --NJOW02
               SET @nTotalWeight = ISNULL(@nTotalWeight,0) * @n_Coefficient_weight             

               UPDATE MBOLDetail SET Weight = @nTotalWeight WHERE MBOLKey = @cMBOLKey AND MBOLLineNumber = @cMBOLLineNumber
               SET @n_err = @@ERROR                  
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=73112
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table MBOL. (ntrMBOLDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  BREAK
               END 
            END
         END
      END
      FETCH NEXT FROM curMD INTO @cMBOLKey, @cMBOLLineNumber, @cOrderKey, @nCurrentTotalCube, @nCurrentTotalWeight, @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5
   END
   CLOSE curMD
   DEALLOCATE curMD
END
 
/* #INCLUDE <TRMBODU2.SQL> */
 IF @n_continue=3  -- Error Occured - Process And Return
 BEGIN
    IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
    execute nsp_logerror @n_err, @c_errmsg, "ntrMBOLDetailUpdate"
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
    RETURN
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