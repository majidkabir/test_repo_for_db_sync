SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispExe2OW_allocpickship_E1                         */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by: June                                                     */  
/*                                                                      */  
/* Purpose:  Replicate base on ispExe2OW_allocpickship - Ver 1.8        */
/*          To generate new line # for orderdetail which has more than  */   
/*          one allocated detail. This is because OW can't accept       */  
/*     multiple detail for each orderdetail line, this new line #       */  
/*     will used to generate new orderdetail record.                    */  
/*                                                                      */  
/* Called By: DX - AllocatePickShip_E.bas                               */  
/*                                                                      */  
/* PVCS Version: 1.8                                                    */  
/*                                                                      */  
/* Version: 5.4.2                                                       */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author      Purposes                                    */  
/* 20.Feb.2003 June     FBR9706(IDSPH - Post Pick Invoicing Trigger)    */  
/* - Insert records into Exe2Ow_allocpickship table if transmitlog's    */  
/*    Tablename is 'OWORDPICK'. It is similar to Pre-Pick Section       */  
/*  except it disallow insertion if same orders appear in 'Pre-Pick'.   */  
/* - Update transmitflag to '5' if records appear in 'Pre-Pick'.        */  
/* 25.Sep.2003  June    Merge Post-Pick changes into Pre-Pick script    */  
/*  - No different after removing checking to prevent One storer        */  
/*  - uses Pre-Pick & Post-Pick at the same time.                       */  
/* 02.Jan.2004  Shong   Performance Tuning                              */  
/* 09.Jul.2004  Wally   SOS27033                                        */  
/* 24.Aug.2005  June    June01 - Bug fixed for problem in SOS27033      */  
/* 14-Jul-2008  Shong   Fixing Bugs                                     */
/* 30-May-2013  SWYep   E1 Trading StoreKey Filter (SW01)               */
/* 23-Jul-2013  SWYep   Added ROWLOCK & NOLOCK to avoid deadlock (SW02) */
/* 14-Apr-2014  TLTING  SQL2012 Fixing Bugs                             */
/* 28-Jan-2019 TLTING_ext 1.2  enlarge externorderkey field length      */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispExe2OW_allocpickship_E1]  
AS  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_ExternLineNo NVARCHAR(10),  
     @c_NewLineNo NVARCHAR(6),  
     @c_Exe2OWLineNo NVARCHAR(3),  
     @n_seqno int,  
     @n_linectr int,  
     @n_err int,  
     @n_cnt int,  
     @n_continue int,  
     @n_starttcnt int,  
     @c_errmsg NVARCHAR(60)           
   DECLARE @b_success int  
   
   DECLARE @c_ListName_E1TStorer NVARCHAR(10)         --(SW01)
   DECLARE @c_Short_E1TStorer NVARCHAR(10)            --(SW01)
  
   SET @c_ListName_E1TStorer = 'E1TStorer'            --(SW01)
   SET @c_Short_E1TStorer = 'E1T'                     --(SW01)
  
BEGIN  
   BEGIN TRANSACTION  
   SELECT @n_continue = 1, @n_starttcnt=@@TRANCOUNT  
  
 -- Assumption : One-World will only either Pre-Pick or Post-Pick. No both Pre-Pick & Post-Pick for any storers.  
/**************************************************************************************************  
 Start - For Pre-Pick : OWORDALLOC (ALLOC-TRF) or OWPREPICK (DPREPICK/ DPREPICK+1)  
    - &  Post-Pick : OWORDPICK (PICK-TRF)   
 *************************************************************************************************/  
  -- Specific Lottable02, Action Code = 'C' & NewLineNo = ''  
   IF EXISTS(SELECT 1 FROM TransmitLog TL (NOLOCK)   
             WHERE TL.TableName IN ('OWORDALLOC', 'OWDPREPICK', 'OWORDPICK')  
             And TL.TransmitFlag = '1')   
   BEGIN  
    INSERT INTO Exe2OW_allocpickship  
    (ExternOrderkey, ExternLineNo,  
    NewLineNo,   Batchno,  
    ActionCode)  
    Select ExternOrderKey = OrderDetail.ExternOrderkey, OrderDetail.ExternLineNo, '', IsNull(OrderDetail.Lottable02, ''), 'N'  
    From OrderDetail With (nolock)   
    Inner Join TransmitLog TL With (nolock) On (TL.Key1 = orderkey And TL.TableName IN ('OWORDALLOC', 'OWDPREPICK', 'OWORDPICK')  
                   And TL.TransmitFlag = '1')  
    Inner Join Orders With (nolock) ON Orders.OrderKey = OrderDetail.OrderKey          --(SW01)            
    Where Orderdetail.Lottable02 <> ''  
    AND NOT EXISTS( SELECT 1 FROM Exe2OW_allocpickship Exe2OW WITH (NOLOCK)         --(SW02)
              Where Exe2OW.Externorderkey = Orderdetail.ExternOrderkey  
              And Exe2OW.ExternLineNo = Orderdetail.ExternLineno)  
    AND NOT EXISTS ( SELECT 1 FROM Codelkup AS CDL WITH (NOLOCK)                                                        --(SW01)
      WHERE CDL.Code = Orders.StorerKey AND CDL.ListName = @c_ListName_E1TStorer AND CDL.Short = @c_Short_E1TStorer )   --(SW01)           
    GROUP BY OrderDetail.ExternOrderkey, OrderDetail.ExternLineNo, IsNull(OrderDetail.Lottable02, '')  
    Order by OrderDetail.ExternOrderKey, OrderDetail.ExternLineNo, IsNull(OrderDetail.Lottable02, '')  
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
    IF @n_err <> 0  
    BEGIN  
         SELECT @n_continue = 3  
     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Exe2OW_allocpickship. (ispExe2OW_allocpickship_E1)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
    END  
  
      -- Empty Lottable02, Action Code = 'A' & NewLineNo = New Line  
    INSERT INTO Exe2OW_allocpickship  
    (ExternOrderkey, ExternLineNo,  
     NewLineNo,   Batchno,  
     ActionCode)  
     Select ExternOrderKey = OrderDetail.ExternOrderkey, OrderDetail.ExternLineNo, '',IsNull(LA.Lottable02, ''), 'N'  
      From OrderDetail With (nolock)   
      Inner Join TransmitLog TL With (nolock) On (TL.Key1 = Orderkey And TL.TableName IN ('OWORDALLOC', 'OWDPREPICK', 'OWORDPICK')  
                    And TL.TransmitFlag = '1')  
      Inner Join Orders With (nolock) ON Orders.OrderKey = OrderDetail.OrderKey           --(SW01)
    Left outer Join Pickdetail With (nolock) On (Pickdetail.Orderkey = Orderdetail.Orderkey And Pickdetail.Orderlinenumber = Orderdetail.OrderLineNumber)  
    Left outer Join LOTAttribute LA (NOLOCK) On (PickDetail.LOT = LA.LOT)   
    Where Orderdetail.Lottable02 = ''   
      AND NOT EXISTS( SELECT 1 FROM Exe2OW_allocpickship Exe2OW  WITH (NOLOCK)         --(SW02)
             Where Exe2OW.Externorderkey = Orderdetail.ExternOrderkey  
             And Exe2OW.ExternLineNo = Orderdetail.ExternLineno  
                               And Exe2OW.BatchNo = LA.Lottable02)  
       AND NOT EXISTS ( SELECT 1 FROM Codelkup AS CDL WITH (NOLOCK)                                                        --(SW01)
         WHERE CDL.Code = Orders.StorerKey AND CDL.ListName = @c_ListName_E1TStorer AND CDL.Short = @c_Short_E1TStorer )   --(SW01)                              
    GROUP BY OrderDetail.ExternOrderkey, OrderDetail.ExternLineNo, IsNull(LA.Lottable02, '')  
    Order by OrderDetail.ExternOrderKey, OrderDetail.ExternLineNo, IsNull(LA.Lottable02, '')  
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
    IF @n_err <> 0  
    BEGIN  
     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Exe2OW_allocpickship. (ispExe2OW_allocpickship_E1)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
    END  
   END -- if exists   
  
/**************************************************************************************************  
 End - For Pre-pick  &  Post-pick  
 *************************************************************************************************/  
  
  
/**************************************************************************************************  
 Start - For Post-Pick : OWORDPICK (PICK-TRF)   
 *************************************************************************************************/  
/* Remark by June 25.Sep.2003  
-- Specific Lottable02, Action Code = 'C' & NewLineNo = ''  
 INSERT INTO Exe2OW_allocpickship  
 (ExternOrderkey, ExternLineNo,  
 NewLineNo,   Batchno,  
 ActionCode)  
 Select ExternOrderKey = OrderDetail.ExternOrderkey, OrderDetail.ExternLineNo, '', IsNull(OrderDetail.Lottable02, ''), 'N'  
 From OrderDetail With (nolock)   
 Inner Join TransmitLog TL With (nolock) On (TL.Key1 = orderkey And TL.TableName = 'OWORDPICK'   
                And TL.TransmitFlag = '1')  
 Where Orderdetail.Lottable02 <> ''  
 -- Remark this for performance, no validation at the moment  
 -- To Prevent One storer uses Pre-Pick & Post-Pick at the same time.  
 -- AND NOT EXISTS (SELECT 1 FROM TransmitLog TL2 (nolock)   
 --           Where TL2.Key1 = TL.Key1 And TL2.TableName IN ('OWORDALLOC', 'OWDPREPICK'))  
 AND NOT EXISTS( SELECT 1 FROM Exe2OW_allocpickship Exe2OW  
           Where Exe2OW.Externorderkey = Orderdetail.ExternOrderkey  
           And Exe2OW.ExternLineNo = Orderdetail.ExternLineno)  
 GROUP BY OrderDetail.ExternOrderkey, OrderDetail.ExternLineNo, IsNull(OrderDetail.Lottable02, '')  
 Order by OrderDetail.ExternOrderKey, OrderDetail.ExternLineNo, IsNull(OrderDetail.Lottable02, '')  
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
 IF @n_err <> 0  
 BEGIN  
      SELECT @n_continue = 3  
  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Exe2OW_allocpickship. (ispExe2OW_allocpickship_E1)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
 END  
  
   -- Empty Lottable02, Action Code = 'A' & NewLineNo = New Line  
 INSERT INTO Exe2OW_allocpickship  
 (ExternOrderkey, ExternLineNo,  
  NewLineNo,   Batchno,  
  ActionCode)  
 Select ExternOrderKey = OrderDetail.ExternOrderkey, OrderDetail.ExternLineNo, '', IsNull(LA.Lottable02, ''), 'N'  
   From OrderDetail With (nolock)   
   Inner Join TransmitLog TL With (nolock) On (TL.Key1 = Orderkey And TL.TableName = 'OWORDPICK'  
                 And TL.TransmitFlag = '1')  
 Left outer Join Pickdetail With (nolock) On (Pickdetail.Orderkey = Orderdetail.Orderkey And Pickdetail.Orderlinenumber = Orderdetail.OrderLineNumber)  
 Left outer Join LOTAttribute LA (NOLOCK) On (PickDetail.LOT = LA.LOT)   
 Where Orderdetail.Lottable02 = ''   
 -- Remark this for performance, no validation at the moment  
 -- To Prevent One storer uses Pre-Pick & Post-Pick at the same time.  
 -- AND NOT EXISTS (SELECT 1 FROM TransmitLog TL2 (nolock)   
  --         Where TL2.Key1 = TL.Key1 And TL2.TableName IN ('OWORDALLOC', 'OWDPREPICK'))  
   AND NOT EXISTS( SELECT 1 FROM Exe2OW_allocpickship Exe2OW  
           Where Exe2OW.Externorderkey = Orderdetail.ExternOrderkey  
           And Exe2OW.ExternLineNo = Orderdetail.ExternLineno  
                            And Exe2OW.BatchNo = LA.Lottable02)  
 GROUP BY OrderDetail.ExternOrderkey, OrderDetail.ExternLineNo, IsNull(LA.Lottable02, '')  
 Order by OrderDetail.ExternOrderKey, OrderDetail.ExternLineNo, IsNull(LA.Lottable02, '')  
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
 IF @n_err <> 0  
 BEGIN  
  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Exe2OW_allocpickship. (ispExe2OW_allocpickship_E1)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
 END  
*/  
  
 -- 'Logged' Post-pick Records if it appears in Pre-Pick  
 IF EXISTS(SELECT 1 FROM  Transmitlog (NOLOCK), Transmitlog TL (nolock)  
           WHERE Transmitlog.Key1 = TL.Key1   
           AND   Transmitlog.Tablename = 'OWORDPICK'  
           AND  TL.Tablename IN ('OWORDALLOC', 'OWDPREPICK')  
             AND   Transmitlog.Transmitflag < '5' )   
 BEGIN  
    UPDATE Transmitlog WITH (ROWLOCK)     --(SW02)   
    SET   Transmitflag = '5'  
    FROM  Transmitlog , Transmitlog TL (nolock)     --(SW02)
    WHERE Transmitlog.Key1 = TL.Key1   
    AND   Transmitlog.Tablename = 'OWORDPICK'  
    AND TL.Tablename IN ('OWORDALLOC', 'OWDPREPICK')  
      AND   Transmitlog.Transmitflag < '5'    
   END   
   
/**************************************************************************************************  
 End - For Post-Pick  
 *************************************************************************************************/  
  
 SELECT @n_seqno = 0  
 SELECT @n_linectr = 100  
  
   DECLARE @c_ExternOrderKey NVARCHAR(50),   --tlting_ext
           @c_PreExternOrderKey NVARCHAR(50),  --tlting_ext
           @b_FirstLine      int,  
           @c_ActionCode     NVARCHAR(1),  
           @c_PreExternLineNo NVARCHAR(10)  
  
   SELECT @c_ExternOrderKey = SPACE(50),  --tlting_ext
          @c_PreExternOrderKey = SPACE(50),  --tlting_ext
          @b_FirstLine = 1,  
          @c_ActionCode = 'C',  
          @c_PreExternLineNo = SPACE(10)  
  
 -- June01 - Start : Fixed problem caused by SOS27033  
 -- Update NewLineNo For ActionCode 'A', NewLineNo = Left(ExternLineNo, 3) + Exe2OWLineNo  
 SELECT @c_ExternLineNo = SPACE(10)  
 /*     
   WHILE 1=1  
   BEGIN  
         SET ROWCOUNT 1  
  
   -- Update NewLineNo For ActionCode 'A', NewLineNo = Left(ExternLineNo, 3) + Exe2OWLineNo  
   SELECT @c_ExternLineNo = SPACE(10)  
  
       SELECT @n_seqno = Seq_no,  
          @c_ExternLineNo = ExternLineNo,  
              @c_ExternOrderKey = ExternOrderKey  
       FROM   Exe2Ow_allocpickship (NOLOCK)  
       WHERE  seq_no > @n_seqno  
       AND    ActionCode = 'N'  
       -- ORDER BY seq_no  
    ORDER BY ExternOrderKey, ExternLineNo, seq_no -- SOS 27033  
   
       IF @@ROWCOUNT = 0  
          BREAK  
   
       SET ROWCOUNT 0           
       */  
        
   SELECT @c_Exe2OWLineNo=''  
   SELECT @b_success=1        
  
   DECLARE ow_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
        SELECT Seq_no, ExternLineNo, ExternOrderKey  
        FROM   Exe2Ow_allocpickship (NOLOCK)  
        WHERE ActionCode = 'N'  
        -- ORDER BY seq_no  
    ORDER BY ExternOrderKey, ExternLineNo, seq_no -- SOS 27033  
     
   OPEN ow_cur      
   FETCH NEXT FROM ow_cur INTO @n_seqno, @c_ExternLineNo, @c_ExternOrderKey  
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN     
   -- June01 - End : Fixed problem caused by SOS27033  
     
        IF @c_ExternOrderKey <> @c_PreExternOrderKey OR @c_PreExternLineNo <> @c_ExternLineNo  
        BEGIN  
           SELECT @n_linectr = 100  
           SELECT @b_FirstLine = 1, @c_ActionCode = 'C', @c_NewLineNo = ''  
        END  
        ELSE  
        BEGIN  
           SELECT @b_FirstLine = 0, @c_ActionCode = 'A'  
           SELECT @n_linectr = @n_linectr + 1  
           SELECT @c_NewLineNo = Convert(char, Convert(Int, @c_ExternLineNo) + @n_linectr)  
        END  
      
        UPDATE Exe2OW_allocpickship WITH (ROWLOCK)    --(SW02)
          SET NewLineNo = @c_NewLineNo,  
              ActionCode = @c_ActionCode,  
              EditDate = GetDate()  
      WHERE seq_no = @n_seqno   
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Exe2OW_allocpickship. (ispExe2OW_allocpickship_E1)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
      END  
     
        SELECT @c_PreExternOrderKey = @c_ExternOrderKey,   
               @c_PreExternLineNo = @c_ExternLineNo  
        
       -- June01 - Start : DX bug problem caused by SOS27033  
        FETCH NEXT FROM ow_cur INTO @n_seqno, @c_ExternLineNo, @c_ExternOrderKey     
     END -- While  
   CLOSE ow_cur  
   DEALLOCATE ow_cur  
   -- END  
   -- SET ROWCOUNT 0  
   -- June01 - End : Fixed problem caused by SOS27033  
  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      ROLLBACK TRAN  
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispExe2OW_allocpickship_E1"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      --RAISERROR @n_err @c_errmsg  
      RETURN  
   END  
   ELSE  
   BEGIN  
      COMMIT TRAN  
   END  
END  


GO