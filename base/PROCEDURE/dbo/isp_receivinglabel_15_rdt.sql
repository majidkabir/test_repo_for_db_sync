SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_receivinglabel_15_rdt                          */
/* Creation Date: 2016-04-29                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#368772 - TH-MINOR New Receipt Label                     */
/*                                                                      */
/* Called By: r_dw_receivinglabel15_rdt                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver.  Purposes                                 */
/* 09-22-2016  MTTey    1.1   IN#0087529 Rec-Qty to go by Sku --MT01    */
/* 10-20-2016  MTTey    1.2   IN#0087529 Fixed Rec-Qty for duplicate sku*/
/*                                       --MT02                         */
/************************************************************************/

CREATE PROC [dbo].[isp_receivinglabel_15_rdt](
    @c_receiptkey         NVARCHAR(10)
   ,@c_receiptline_start  NVARCHAR(5) = ''
   ,@c_receiptline_End    NVARCHAR(5) = ''
   ,@c_toid               NVARCHAR(18) = ''
 )
 AS
 BEGIN
  SET NOCOUNT ON
  SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE
           @c_RecLineNo       NVARCHAR(5),            --MT02
           @c_Condition       NVARCHAR(4000),
           @c_SQLStatement    NVARCHAR(3999) ,
           @c_getreceiptkey   NVARCHAR(10),
           @c_gettoid         NVARCHAR(18),
           @n_GetRecqty       INT,
           @n_BRecvqty        INT,
           @n_Recvqty         INT,
           @c_sku             NVARCHAR(20)

  CREATE TABLE #RECVRESULT15 (
  	Storerkey            NVARCHAR(15) NULL,
  	Brand                NVARCHAR(18) NULL,
  	CartonID             NVARCHAR(18) NULL,
  	Season               NVARCHAR(30) NULL,
  	HAWBNo               NVARCHAR(18) NULL,
  	Receiptdate          NVARCHAR(10) NULL ,
  	Line                 NVARCHAR(150) NULL,
  	Receiptkey           NVARCHAR(10) NULL,
  	RecExternReceiptKey  NVARCHAR(20) NULL,
  	SKU                  NVARCHAR(20) NULL,
  	Style                NVARCHAR(20) NULL,
  	color                NVARCHAR(10) NULL,
  	sku_size             NVARCHAR(10) NULL,
  	RecQtyRec            INT,
  	Price                FLOAT,
  	ReceiveBy            NVARCHAR(18),
  	RecLineNo            NVARCHAR(5)  NULL,

  	)

  	SET @n_GetRecqty = 0
  	SET @n_BRecvqty = 0
  	SET @n_Recvqty = 0


   IF ISNULL(@c_toid,'') <> ''
   BEGIN
   	SET @c_Condition = ' AND RECDET.TOID = ''' + @c_toid + ''''
   END
   /* -- MT01 --IN#0087529
   ELSE
   	BEGIN
   	  SET	@c_Condition = 'AND ( RECDET.ReceiptlineNumber >= ''' + @c_receiptline_start + ''')                            ' +
							      'AND ( RECDET.ReceiptLineNumber <= ''' + @c_receiptline_end  + ''') 	                           ' +
   	                     ' AND RECDET.TOID <> '''' '
   	END
        -- MT01 */
   SELECT @c_SQLStatement = 'SELECT DISTINCT Storerkey    = REC.StorerKey, ' +
									 'Brand                = SKU.SUSR3,    ' +
									 'CartonID             = RECDET.TOID,  ' +
									 'Season               = SKU.BUSR7,    ' +
									 'HAWBNo               = REC.Carrierreference,' +
									 'Receiptdate      = CONVERT(NVARCHAR(10),REC.ReceiptDate,126),' +
									 'Line                 = CL.Description,' +
									 'Receiptkey = REC.ReceiptKey,  ' +
									 'RecExternReceiptKey  = REC.ExternReceiptKey,' +
									 'Sku                  = RECDET.Sku,' +
									 'Style                = SKU.Style,' +
									 'color                = SKU.Color,' +
									 'sku_size             = SKU.Size,' +
								  --'RecQtyRec            = RECDET.QtyReceived, ' +
									 'RecQtyRec            = 0, ' +
									 'Price                = SKU.Cost,' +
									 'ReceiveBy            = CASE WHEN ISNULL(r.UserName,'''') <> '''' THEN r.fullname ELSE RECDET.Editwho END,  ' +
									 'RecLineNo            = RECDET.ReceiptLineNumber                                                           ' +                --MT02
							 	 -- 'INTO #RECVRESULT15                                                                                        ' +
									 'FROM RECEIPT REC WITH (NOLOCK)																										' +
									 'JOIN RECEIPTDETAIL RECDET (NOLOCK)  ON RECDET.ReceiptKey = REC.ReceiptKey											' +
									 'JOIN SKU (NOLOCK) ON SKU.StorerKey = RECDET.StorerKey AND SKU.Sku = RECDET.Sku										' +
									 'LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.listname=''MINORCLASS'' AND CL.code = SKU.class 					   ' +
									 'LEFT JOIN Rdt.RDTUser AS r WITH (NOLOCK) ON r.UserName=recdet.editwho												   ' +
									 'WHERE  ( RECDET.ReceiptKey = ''' + @c_receiptkey + ''' )                                                  '
							--		 '			( RECDET.ReceiptlineNumber >= ''' + @c_receiptline_start + ''') AND                         ' +
							--		 '			( RECDET.ReceiptLineNumber <= ''' + @c_receiptline_end  + ''') 	 						      '

	 INSERT INTO #RECVRESULT15
    EXEC(@c_SQLStatement + @c_condition)

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT receiptkey,CartonID,sku,RecLineNo                                      --MT02
   FROM   #RECVRESULT15
   WHERE CartonID = CASE WHEN ISNULL(@c_toid,'') <> '' THEN @c_toid ELSE CartonID END

   OPEN CUR_RESULT

   FETCH NEXT FROM CUR_RESULT INTO @c_getreceiptkey,@c_gettoid,@c_sku,@c_RecLineNo

   WHILE @@FETCH_STATUS <> -1
   BEGIN


  /* --MT01
   SELECT @n_BRecvqty = SUM(BeforeReceivedqty),@n_Recvqty=SUM(qtyreceived)
   FROM RECEIPTDETAIL AS r  WITH (NOLOCK)
   WHERE receiptkey = @c_getreceiptkey
   AND toid = @c_gettoid
  --MT01 */

   SELECT @n_BRecvqty = BeforeReceivedqty,@n_Recvqty=qtyreceived
   FROM RECEIPTDETAIL AS r  WITH (NOLOCK)
   WHERE receiptkey = @c_getreceiptkey
   AND toid = @c_gettoid
   AND SKU = @c_sku
   AND ReceiptLineNumber = @c_RecLineNo                                 --MT02

   IF @n_BRecvqty > 0
   BEGIN
   	SELECT @n_GetRecqty = @n_BRecvqty
   END
   ELSE
    BEGIN
   	SELECT @n_GetRecqty = @n_Recvqty
   END

  /* --MT01
   UPDATE #RECVRESULT15
   SET RecQtyRec =@n_GetRecqty
   WHERE Receiptkey = @c_getreceiptkey
   AND CartonID = @c_gettoid
    --MT01 */

   UPDATE #RECVRESULT15
   SET RecQtyRec =@n_GetRecqty
   WHERE Receiptkey = @c_getreceiptkey
   AND CartonID = @c_gettoid
   AND sku=@c_sku
   AND RecLineNo = @c_RecLineNo                                                        --MT02

   FETCH NEXT FROM CUR_RESULT INTO @c_getreceiptkey,@c_gettoid,@c_sku,@c_RecLineNo     --MT02
   END

   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT

   SELECT *
   FROM #RECVRESULT15
   ORDER BY Receiptkey,CartonID

   DROP TABLE #RECVRESULT15
 END


GO