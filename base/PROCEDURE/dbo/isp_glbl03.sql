SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GLBL03                                         */
/* Creation Date: 28-Jan-2014                                           */
/* Copyright: IDS                                                       */
/* Written by: Chew KP                                                  */
/*                                                                      */
/* Purpose: SOS#293508 - Generate ANF UCC Label No                      */
/*                                                                      */
/* Called By: isp_AutoPackLoad                                          */ 
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
/* Date         Author    Ver.  Purposes                                */
/* 2014-05-14   Chee      1.1   Bug Fix - Include consigneeKey filter   */ 
/*                              when selecting Brand (Chee01)           */ 
/* 2014-06-03   ChewKP    1.2   Add in TraceInfo (ChewKP01)             */
/* 2014-06-05   Chee      1.3   Prevent error when pickslip has child   */
/*                              order generated (Chee02)                */  
/* 2021-09-22   CSCHONG   1.4   WMS-17959 revised field logic (CS01)    */
/* 2021-11-25   CSCHONG   1.5   Devops scripts combine                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL03] (
   @c_PickSlipNo         NVARCHAR(10), 
   @n_CartonNo           INT,  
   @c_LabelNo            NVARCHAR(20)   OUTPUT, -- Pass in DropID , Output LabelNo
   @cStorerKey           NVARCHAR( 15) = '',
   @cDeviceProfileLogKey NVARCHAR(10)  = '', 
   @cConsigneeKey        NVARCHAR(15)  = '',
   @b_success            int = 0 OUTPUT ,
   @n_err                int = 0 OUTPUT,
   @c_errmsg             NVARCHAR(225) = '' OUTPUT
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
	DECLARE 	
   @cIdentifier    NVARCHAR( 2),
	@cPacktype      NVARCHAR( 1),
   @cSUSR1         NVARCHAR( 20),
   @c_nCounter     NVARCHAR( 25),
   @nCheckDigit    INT,
   @nTotalCnt      INT,
   @nTotalOddCnt   INT,
   @nTotalEvenCnt  INT,
   @nAdd           INT,
   @nDivide        INT,
   @nRemain        INT,
   @nOddCnt        INT,
   @nEvenCnt       INT,
   @nOdd           INT,
   @nEven          INT,
   @cBrand         NVARCHAR(1),
   @cOrderType     NVARCHAR(10),
   --@cConsigneeKey  NVARCHAR(5),
   @cLabelFlag     NVARCHAR(1),
   @cConsigneeCartonNo NVARCHAR(5),
   @cDCNo          NVARCHAR(2),
   @cFacility      NVARCHAR(5),
   @cVendorNo      NVARCHAR(7),
   @cDCtoDCCartonNo NVARCHAR(9),
   @cPackageType    NVARCHAR(2),
   @cContainerType  NVARCHAR(1),
   @cDropID         NVARCHAR(20),
   @cFaclity        NVARCHAR(5),
   @nTry            INT,
   @c_TempLabelNo   NVARCHAR(20), 
   @bDebug          INT,
   @c_getConsigneeKey  NVARCHAR(30)    --CS01
   
   
   

   IF ISNULL(RTRIM(@c_LabelNo),'') = ''
   BEGIN
      SET @c_LabelNo = ''
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
      SET @n_err = 80000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid module for Packing' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         
      execute nsp_logerror @n_err, @c_errmsg, 'isp_GLBL03'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      GOTO QUIT
   END   
      
   SET @cDropID = @c_LabelNo
      

	SELECT @b_success = 1, @c_errmsg='', @n_err=0 
	
	SET @cVendorNo             = ''
	SET @cFacility             = ''
	SET @cOrderType            = ''
	SET @cLabelFlag            = ''
	--SET @cConsigneeKey         = ''
	SET @cConsigneeCartonNo    = ''
	SET @nCheckDigit           = ''
	SET @c_LabelNo              = ''
	SET @cDCtoDCCartonNo       = ''
	SET @cPackageType          = ''
	SET @cContainerType        = ''
   SET @cFacility             = ''
   SET @nTry                  = 0 
   SET @bDebug                = 1
	
   IF EXISTS (SELECT 1 FROM StorerConfig WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigKey = 'GenUCCLabelNoConfig'
         AND SValue = '1')
   BEGIN
     SELECT TOP 1  @cOrderType = O.Type 
                 , @cFacility  = O.Facility
     FROM dbo.PickDetail PD WITH (NOLOCK) 
     INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
     INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.SKU = PD.SKU
     --INNER JOIN dbo.PackDetail PackD WITH (NOLOCK) ON PackD.PickslipNo = PD.PickSlipNo AND PackD.SKU = PD.SKU
     WHERE PD.PickSlipNo = @c_PickSlipNo
     --AND PackD.DropID = @cDropID
     AND PD.Status IN ( '3','5') 
     AND O.Type <> 'CHDORD' -- (Chee02)
     

     IF @@ROWCOUNT = 0
      GOTO QUIT


     IF ISNULL(RTRIM(@cOrderType),'') IN ('DCtoDC','StrtoIRL', 'Destroy')
     BEGIN
         SET @cLabelFlag = '0' -- DC to DC
     END
     ELSE
     BEGIN
         SET @cLabelFlag = '1' -- DC to Store
     END
     
     IF @cLabelFlag = '0'
     BEGIN
         SET @cPackageType   = '00'
         SET @cContainerType = '0'
         
         SELECT @cVendorNo = Short
         FROM dbo.CodeLkup WITH (NOLOCK)
         WHERE ListName = 'ANFFAC'
         AND Code = @cFacility 
         
         SET @cVendorNo = RIGHT('0000000' + CAST(RTRIM(@cVendorNo) AS VARCHAR(7)), 7) 
         
         
         EXECUTE nspg_getkey
       	        'ANFDCtoDC'
       	      , 9
       	      , @cDCtoDCCartonNo OUTPUT
       	      , @b_success OUTPUT
       	      , @n_err OUTPUT
       	      , @c_errmsg OUTPUT
         
         SET @c_TempLabelNo = @cPackageType + @cContainerType + @cVendorNo + @cDCtoDCCartonNo 
         
         SET @nOdd = 1
         SET @nOddCnt = 0
         SET @nTotalOddCnt = 0
         SET @nTotalCnt = 0
         
         WHILE @nOdd <= 20 
         BEGIN
		       SET @nOddCnt = CAST(SUBSTRING(@c_TempLabelNo, @nOdd, 1) AS INT)
		       SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
		       SET @nOdd = @nOdd + 2
         END

	      SET @nTotalCnt = (@nTotalOddCnt * 3) 
	
	      SET @nEven = 2
         SET @nEvenCnt = 0
         SET @nTotalEvenCnt = 0

	      WHILE @nEven <= 20 
         BEGIN
		      SET @nEvenCnt = CAST(SUBSTRING(@c_TempLabelNo, @nEven, 1) AS INT)
		      SET @nTotalEvenCnt = @nTotalEvenCnt + @nEvenCnt
		      SET @nEven = @nEven + 2
	      END

         SET @nAdd = 0
         SET @nRemain = 0
         SET @nCheckDigit = 0

	      SET @nAdd = @nTotalCnt + @nTotalEvenCnt
	      SET @nRemain = @nAdd % 10
	      SET @nCheckDigit = 10 - @nRemain

	      IF @nCheckDigit = 10 
			  SET @nCheckDigit = 0
         
         SET @c_LabelNo = @cPackageType + @cContainerType + @cVendorNo + @cDCtoDCCartonNo + CAST ( @nCheckDigit AS NVARCHAR(1))
         
     END
     ELSE IF @cLabelFlag = '1'
     BEGIN
        REGEN_LABELNO:
        
        SET @cBrand = ''

        SELECT TOP 1 @cFacility = O.Facility 
        FROM dbo.PickDetail PD WITH (NOLOCK)
        INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
        WHERE PD.PickSlipNo = @c_PickSlipNo
        
        
        SELECT @cDCNo = Short 
        FROM dbo.Codelkup WITH (NOLOCK)
        WHERE LISTNAME = 'ANFFAC'
        AND Code = @cFacility

        IF @cDeviceProfileLogKey <> '' 
        BEGIN
           SET @cConsigneeKey = ''
           
           SELECT TOP 1 @cConsigneeKey = ConsigneeKey
           FROM dbo.DeviceProfileLog WITH (NOLOCK)
           WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
           AND DropID = @cDropID
           AND Status = '3'
        END

        --CS01 START

        SET @c_getConsigneeKey = ''
        IF EXISTS (SELECT 1 FROM CODELKUP C WITH (NOLOCK) WHERE C.LISTNAME = 'ANFBRANDS' AND C.Storerkey=@cStorerKey AND C.code=@cFacility AND c.UDF01 ='1')
        BEGIN
             SELECT @cBrand = ST.Secondary
             FROM STORER ST WITH (NOLOCK)
             WHERE ST.StorerKey = @cConsigneeKey AND ST.type ='2'
        END
        ELSE
        BEGIN
            -- Need to clarify on the Brand is what -- 
              SELECT TOP 1 @cBrand = OD.UserDefine01
              FROM dbo.PickDetail PD WITH (NOLOCK) 
              INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
              INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.SKU = PD.SKU
              WHERE PD.PickSlipNo = @c_PickSlipNo
              AND OD.UserDefine02 = @cConsigneeKey -- (Chee01)  
        END
  
        --CS01 END

       

        -- (Chee01)
        SET @cConsigneeKey = RIGHT(@cConsigneeKey, 5) 

-- (Chee01)
--        IF @cDeviceProfileLogKey <> '' 
--        BEGIN
--           SET @cConsigneeKey = ''
--           
--           SELECT TOP 1 @cConsigneeKey = RIGHT(ConsigneeKey, 5) 
--           FROM dbo.DeviceProfileLog WITH (NOLOCK)
--           WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
--           AND DropID = @cDropID
--           AND Status = '3'
--        END
--        ELSE
--        BEGIN
--            SET @cConsigneeKey = RIGHT(@cConsigneeKey, 5) 
--        END

        -- Check If NCount Exist with ConsigneeKey
        IF EXISTS ( SELECT 1 FROM dbo.NCounter WHERE KeyName = @cConsigneeKey ) 
        BEGIN
            
            IF @nTry = 0 
            BEGIN
               EXECUTE nspg_getkey
          	        @cConsigneeKey
          	      , 5
          	      , @cConsigneeCartonNo OUTPUT
          	      , @b_success OUTPUT
          	      , @n_err OUTPUT
          	      , @c_errmsg OUTPUT
       	   END
        END
        ELSE
        BEGIN
            INSERT INTO dbo.NCounter ( KeyName , KeyCount ) 
            VALUES ( @cConsigneeKey, 1 ) 
            
            SET @cConsigneeCartonNo =  '00001'

        END

        
        SET @nCheckDigit = 10 - (((CAST (@cBrand AS INT) * 3) 
                           + (SUBSTRING(@cConsigneeKey, 1,1 )  * 7)
                           + (SUBSTRING(@cConsigneeKey, 2,1 )  * 1)
                           + (SUBSTRING(@cConsigneeKey, 3,1 )  * 3)
                           + (SUBSTRING(@cConsigneeKey, 4,1 )  * 7)
                           + (SUBSTRING(@cConsigneeKey, 5,1 )  * 1)
                           + (SUBSTRING(@cConsigneeCartonNo, 1,1 ) * 3)
                           + (SUBSTRING(@cConsigneeCartonNo, 2,1 ) * 7)
                           + (SUBSTRING(@cConsigneeCartonNo, 3,1 ) * 1)
                           + (SUBSTRING(@cConsigneeCartonNo, 4,1 ) * 3)
                           + (SUBSTRING(@cConsigneeCartonNo, 5,1 ) * 7)) % 10)
       
       IF @nCheckDigit = 10 
       BEGIN
         SET @nCheckDigit = 0 
       END

       SET @c_LabelNo = RTRIM(@cBrand) + RTRIM(@cConsigneeKey) + RTRIM(@cConsigneeCartonNo) + CAST ( @nCheckDigit AS NVARCHAR(1)) + RTRIM(@cDCNo)
       
       
       
       SET @nTry = @nTry + 1 
       
       -- (ChewKP01)
       IF @bDebug = 1
       BEGIN
           INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
           VALUES ( 'GLBL03', GETDATE(), @cDropID, @c_LabelNo, @cConsigneeKey, @cLabelFlag, @cConsigneeCartonNo )
       END
       
       IF LEN(RTRIM(@c_LabelNo)) <> 14
       BEGIN
         IF @nTry = 3 
         BEGIN
            GOTO QUIT
         END
         
         GOTO REGEN_LABELNO
       END

        
--        SET @cIdentifier = '00'
--   	  SET @cPacktype = '0'  
--        SET @c_LabelNo = ''
--   
--        SELECT @cSUSR1 = ISNULL(SUSR1, '0')
--   	   FROM Storer WITH (NOLOCK)
--   	   WHERE Storerkey = @cStorerkey
--   	   AND Type = '1'
--   
--   	  IF LEN(@cSUSR1) >= 9 
--        BEGIN
--     	    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60201   
--   	      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid part barcode. (isp_GLBL03)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
--   	      SELECT @b_success = 0
--   		    GOTO Quit
--        END 
--   
--   	  EXEC isp_getucckey
--   			@cStorerkey,
--   			9,
--   			@c_nCounter OUTPUT ,
--   			@b_success  OUTPUT,
--   			@n_err      OUTPUT,
--   			@c_errmsg   OUTPUT,
--   			0,
--   			1
--   
--   	  IF LEN(@cSUSR1) <> 8 
--            SELECT @cSUSR1 = RIGHT('0000000' + CAST(@cSUSR1 AS NVARCHAR( 7)), 7)
--   
--   	  SET @c_LabelNo = @cIdentifier + @cPacktype + RTRIM(@cSUSR1) + RTRIM(@c_nCounter) --+ @nCheckDigit
--   
--   	  SET @nOdd = 1
--        SET @nOddCnt = 0
--        SET @nTotalOddCnt = 0
--        SET @nTotalCnt = 0
--   
--        WHILE @nOdd <= 20 
--        BEGIN
--   		   SET @nOddCnt = CAST(SUBSTRING(@c_LabelNo, @nOdd, 1) AS INT)
--   		   SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
--   		   SET @nOdd = @nOdd + 2
--        END
--   
--   	  SET @nTotalCnt = (@nTotalOddCnt * 3) 
--   	
--   	  SET @nEven = 2
--        SET @nEvenCnt = 0
--        SET @nTotalEvenCnt = 0
--   
--   	  WHILE @nEven <= 20 
--        BEGIN
--   		   SET @nEvenCnt = CAST(SUBSTRING(@c_LabelNo, @nEven, 1) AS INT)
--   		   SET @nTotalEvenCnt = @nTotalEvenCnt + @nEvenCnt
--   		   SET @nEven = @nEven + 2
--   	  END
--   
--        SET @nAdd = 0
--        SET @nRemain = 0
--        SET @nCheckDigit = 0
--   
--   	  SET @nAdd = @nTotalCnt + @nTotalEvenCnt
--   	  SET @nRemain = @nAdd % 10
--   	  SET @nCheckDigit = 10 - @nRemain
--   
--   	  IF @nCheckDigit = 10 
--   			  SET @nCheckDigit = 0
--   
--   	  SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
     END
   END   -- GenUCCLabelNoConfig
--   ELSE
--   BEGIN
--      EXECUTE nspg_GetKey
--         'PACKNO', 
--         10 ,
--         @c_LabelNo   OUTPUT,
--         @b_success  OUTPUT,
--         @n_err      OUTPUT,
--         @c_errmsg   OUTPUT
--   END
   Quit:

END

GO