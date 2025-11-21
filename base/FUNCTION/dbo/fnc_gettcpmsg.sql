SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Stored Procedure: fnc_GetTCPMsg                                      */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-04-2012   Shong         Initial                                   */
/************************************************************************/ 
CREATE FUNCTION [dbo].[fnc_GetTCPMsg]
(
   @cSearchString NVARCHAR( Max) = ''
)     
RETURNS @tCartonCloseDetail TABLE     
(    
    SerialNo         INT  NOT NULL,    
    MessageNum       NVARCHAR(8)  NOT NULL,    
    MessageName      NVARCHAR(15) NOT NULL,    
    OrderKey         NVARCHAR(10) NOT NULL,  
    OrderLineNumber  NVARCHAR( 5) NOT NULL,  
    ConsoOrderKey    NVARCHAR(30) NOT NULL,  
    SKU              NVARCHAR(20) NOT NULL,
    QtyExpected      INT         NOT NULL,           
    Qty              INT         NOT NULL,  
    LPNNo            NVARCHAR(20) NOT NULL,  
    Status           NVARCHAR(1)  NOT NULL, 
    ErrMsg           NVARCHAR(400) NOT NULL,
    AddDate          DATETIME     NOT NULL,
    AddWho           NVARCHAR(215) NOT NULL, 
    EditDate         DATETIME     NOT NULL, 
    EditWho          NVARCHAR(215) NOT NULL
)    
AS    
BEGIN  
   DECLARE @t_CartonCloseRecord TABLE (SeqNo INT, LineText NVARCHAR(512))    
  
   DECLARE @c_DataString NVARCHAR(MAX)  
   DECLARE @nSerialNo    INT    
   
	-- SELECT ALL DATA
	DECLARE CUR_INLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	SELECT [Data], SerialNo
	FROM   dbo.TCPSocket_INLog WITH (NOLOCK)    
	WHERE  Data LIKE @cSearchString
       
   OPEN CUR_INLOG    
   FETCH NEXT FROM CUR_INLOG INTO @c_DataString, @nSerialNo
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      --ALLOCMOVE
		IF LEFT( @c_DataString, LEN( 'ALLOCMOVE')) = 'ALLOCMOVE'
		BEGIN
		   INSERT INTO @tCartonCloseDetail (SerialNo, MessageNum, MessageName, OrderKey, OrderLineNumber, ConsoOrderKey, SKU, QtyExpected, Qty, LPNNo, Status, ErrMsg, AddDate, AddWho, EditDate, EditWho)
		   SELECT SerialNo, MessageNum, InMsgType, OrderKey, OrderLineNumber, ConsoOrderKey, SKU, Qty_Expected, Qty_Actual, LPNNo, Status, ErrMsg, AddDate, AddWho, EditDate, EditWho
		   FROM V_TCP_WCS_BULK_PICK_IN
		   WHERE SerialNo = @nSerialNo
		END
		
		-- FULLCASE
		IF LEFT( @c_DataString, LEN( 'FULLCASE')) = 'FULLCASE'
		BEGIN
		   INSERT INTO @tCartonCloseDetail (SerialNo, MessageNum, MessageName, OrderKey, OrderLineNumber, ConsoOrderKey, SKU, QtyExpected, Qty, LPNNo, Status, ErrMsg, AddDate, AddWho, EditDate, EditWho)
		   SELECT SerialNo, MessageNum, InMsgType, OrderKey, OrderLineNumber, ConsoOrderKey, SKU, 0, Qty_Actual, LPNNo, Status, ErrMsg, AddDate, AddWho, EditDate, EditWho
		   FROM dbo.V_TCP_WCS_FC_INDUCTION_IN
         WHERE SerialNo = @nSerialNo
		END		
		
		-- CARTONCLOSE
		IF LEFT( @c_DataString, LEN( 'CARTONCLOSE')) = 'CARTONCLOSE'
		BEGIN
		   INSERT INTO @tCartonCloseDetail (SerialNo, MessageNum, MessageName, OrderKey, OrderLineNumber, ConsoOrderKey, SKU, QtyExpected, Qty, LPNNo, Status, ErrMsg, AddDate, AddWho, EditDate, EditWho)
		   SELECT d.SerialNo, d.MessageNum, d.MessageName, d.OrderKey, d.OrderLineNumber, d.ConsoOrderKey, d.SKU, d.QtyExpected, d.Qty, h.LPNNo, 
            h.Status, h.ErrMsg, h.AddDate, h.AddWho, h.EditDate, h.EditWho
		   FROM fnc_GetTCPCartonCloseHeader( @nSerialNo) h
            join fnc_GetTCPCartonCloseDetail( @nSerialNo) d on (h.serialno = d.serialno)
		END
			
		-- ALLOCSHORT
		IF LEFT( @c_DataString, LEN( 'ALLOCSHORT')) = 'ALLOCSHORT'
		BEGIN
		   INSERT INTO @tCartonCloseDetail (SerialNo, MessageNum, MessageName, OrderKey, OrderLineNumber, ConsoOrderKey, SKU, QtyExpected, Qty, LPNNo, Status, ErrMsg, AddDate, AddWho, EditDate, EditWho)
		   SELECT SerialNo, MessageNum, InMsgType, OrderKey, OrderLineNumber, ConsoOrderKey, SKU, 0, QtyShorted, '', Status, ErrMsg, AddDate, AddWho, EditDate, EditWho
		   FROM dbo.V_TCP_ALLOCATED_SHORT_IN
         WHERE SerialNo = @nSerialNo
		END

		FETCH NEXT FROM CUR_INLOG INTO @c_DataString, @nSerialNo
	END  -- WHILE CUR_INLOG
   RETURN    
END

GO