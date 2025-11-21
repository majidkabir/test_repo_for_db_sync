SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_TCP_GSILabel                                    */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Write GSI label and move to TCP Port                        */  
/*                                                                      */  
/* Called from: rdtfnc_Scan_And_Pack                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author    Purposes                                  */  
/* 31-Mar-2011 1.0  Shong     Created                                   */  
/*                            TCP Printing Features for Bartender       */ 
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_TCP_GSILabel] (  
   @nSPID             INT,  
   @cPrinterID        NVARCHAR(50),
   @nErrNo            INT          OUTPUT,   
   @cErrMsg           NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN  
     
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
     
   DECLARE   
      @b_success         INT,  
      @n_err             INT,  
      @c_errmsg          NVARCHAR( 255)  
     
   DECLARE   
      @cLineText         NVARCHAR( 1500),  
      @cFullText         NVARCHAR(MAX),   
      @nFirstTime        INT  
  
   DECLARE    @n_debug        int  
  
   SET @n_debug = 0  
   -- SHONG01         
   DECLARE @c_TCP_IP        NVARCHAR(20),
           @c_TCP_Port      NVARCHAR(10),
           @c_BatchNo       NVARCHAR(20)   
           
   SET @c_BatchNo = ABS(CAST(CAST(NEWID() AS VARBINARY(5)) AS Bigint))    
   
   -- SHONG01
   -- Get Printer TCP 
   SELECT @b_success = 0  

   SET @c_TCP_IP = ''
   SET @c_TCP_Port = ''
   
   SELECT @c_TCP_IP   = Long, 
          @c_TCP_Port = Short
   FROM CODELKUP c (NOLOCK)
   WHERE c.LISTNAME = 'TCPPrinter' 
   AND c.Code = @cPrinterID
                 
   INSERT INTO XML_Message( BatchNo, Server_IP, Server_Port, XML_Message, RefNo )
   SELECT @c_BatchNo, @c_TCP_IP, @c_TCP_Port, LineText, ''
   FROM RDT.RDTGSICartonLabel_XML WITH (NOLOCK)   
   WHERE SPID = @nSPID  
   ORDER BY SeqNo
   
   -- SHONG01
   IF EXISTS(SELECT 1 FROM XML_Message xm (NOLOCK)
             WHERE xm.BatchNo = @c_BatchNo 
             AND   xm.[Status] = '0')
   BEGIN
      EXEC isp_TCPProcess @c_BatchNo
   END
        
   Quit:  
END  

GO