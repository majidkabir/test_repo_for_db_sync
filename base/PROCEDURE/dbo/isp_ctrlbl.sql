SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_CTRLBL                              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: SHONG                                                    */
/*                                                                      */
/* Purpose: SOS166181                                                   */
/*                                                                      */
/* Called By: WMS Pick & Pack Module                                    */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 21-Jun-2010  NJOW01    1.1  178441 - Change Packheader to Pickheader */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_CTRLBL]
   @cPickSlipNo NVARCHAR(10),
   @nCartonNo INT=0,
   @cNewLabelNo NVARCHAR(20)='' OUTPUT
AS
BEGIN
    SET NOCOUNT ON
    SET ANSI_DEFAULTS OFF  
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @cDoor      NVARCHAR(10),
            @cWHCode    NVARCHAR(10),
            @cFacility  NVARCHAR(5), 
            @cSerialNo  NVARCHAR(7),
            @bSuccess   INT,
            @nErr       INT,
            @cErrMsg    NVARCHAR(250),
            @nCheckDigit int,
            @nNewLabelNo BIGINT
            
    SELECT @cDoor = O.DOOR,
           @cWHCode = ISNULL(c.Code,'') 
    FROM PICKHEADER p WITH (NOLOCK) 
    INNER JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey 
    LEFT OUTER JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'CARTERFAC' AND c.Short = o.Facility
    WHERE p.PickHeaderKey = @cPickSlipNo 
    
    IF ISNULL(RTRIM(@cWHCode),'') = ''
    BEGIN
       SET @cNewLabelNo = ''
       GOTO EXIT_PROC 
    END
    
    IF @cDoor = '02'
    BEGIN
       SET @cNewLabelNo = '0000015674' + RTRIM(@cWHCode)

    END 
    ELSE 
    BEGIN
       SET @cNewLabelNo = '0000019718' + RTRIM(@cWHCode)        
    END
    
    IF ISNUMERIC(@cNewLabelNo) = 1 
    BEGIN 
       EXEC nspg_GetKey
          @KeyName = 'CARTERLABELNO',
          @fieldlength = 7,
          @keystring = @cSerialNo OUTPUT,
          @b_Success = @bSuccess OUTPUT,
          @n_err = @nErr OUTPUT,
          @c_errmsg = @cErrMsg OUTPUT,
          @b_resultset = 0,
          @n_batch = 1 

       IF @bSuccess = 1
       BEGIN
          SET @cNewLabelNo = RTRIM(@cNewLabelNo) + RTRIM(@cSerialNo) 
       END
       ELSE
       BEGIN
          SET @cNewLabelNo = ''
          GOTO EXIT_PROC           
       END

       --SET @nCheckDigit = CAST(@cNewLabelNo AS BIGINT) % 10 
       SET @nNewLabelNo = CAST(@cNewLabelNo AS BIGINT) 
       EXEC isp_CheckDigits  
        @inum = @nNewLabelNo, 
	      @onum = @nCheckDigit OUTPUT 

       --SET @cNewLabelNo = @cNewLabelNo + CAST(@nCheckDigit AS NVARCHAR(2))	     	   	      
       SET @cNewLabelNo = @cNewLabelNo + RIGHT(RTRIM(CAST(@nCheckDigit AS NVARCHAR(2))),1)

    END 
    ELSE   
    BEGIN
       SET @cNewLabelNo = ''
       GOTO EXIT_PROC 
    END
   
EXIT_PROC:
RETURN
 
END

GO