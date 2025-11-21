SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispORD03                                           */
/* Creation Date: 25-APR-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1706 TW-E-Land create tracking# for EC's order          */   
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */ 
/*25/11/2019    WLChooi  1.1  WMS-11205 - Include Update action (WL01)  */
/*04/12/2019    WLChooi  1.2  Fixed to use Local cursor (WL02)          */
/*30/01/2020    NJOW01   1.3  WMS-11913 new format for shipperkey 711   */
/*06/04/2020    WLChooi  1.4  WMS-12775 Update UserDefine10 = @c_UDF05  */
/*                            instead of UserDefine09 (WL03)            */
/*08/12/2020    WLChooi  1.5  WMS-15815 Cater for Shipperkey = 'Family' */
/*                            (WL04)                                    */
/*21/01/2022    CSCHONG  1.6  Devops Scripts Combine & WMS-18716(CS01)  */
/*15/08/2023    NJOW02   1.7  WMS-23422 Update M_company by config      */ 
/*15/08/2023    NJOW02   1.7  DEVOPS Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[ispORD03]   
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_Orderkey        NVARCHAR(10),
           @c_ShipperKey      NVARCHAR(15),
           @c_UDF01           NVARCHAR(60),
           @c_UDF02           NVARCHAR(60),
           @c_UDF03           NVARCHAR(60),
           @c_UDF05           NVARCHAR(60),
           @c_Code            NVARCHAR(30),
           @c_TrackingNo      NVARCHAR(60),
           @c_MarkforKey      NVARCHAR(15),
           @c_CI_Short        NVARCHAR(10),
           @c_CI_UDF02        NVARCHAR(60),
           @n_len             INT,
           @c_OrderInfo07     NVARCHAR(30)

   --WL04 START
   DECLARE @c_CI_UDF03        NVARCHAR(60)
         , @c_CI_UDF01        NVARCHAR(60) 
         , @c_CI_Long         NVARCHAR(250)
         , @c_SUSR1           NVARCHAR(20) 
         , @c_SUSR2           NVARCHAR(20) 
         , @c_SUSR3           NVARCHAR(20)  
 
   DECLARE @c_GetCheckASec1 NVARCHAR(4000)
         , @c_GetCheckASec2 NVARCHAR(4000)
         , @n_Sec1a         INT
         , @n_Sec1b         INT
         , @n_Sec1          INT
         , @c_GetCheckA     NVARCHAR(4000)

   DECLARE @c_GetCheckBSec1 NVARCHAR(4000)
         , @c_GetCheckBSec2 NVARCHAR(4000)
         , @n_Sec2a         INT
         , @n_Sec2b         INT
         , @n_Sec2          INT
         , @c_GetCheckB     NVARCHAR(4000)

   DECLARE @c_GetSec        NVARCHAR(4000)
         , @c_GetCheckC     NVARCHAR(4000) 
         
   DECLARE @c_M_VAT         NVARCHAR(18)
         , @c_OrderInfo08   NVARCHAR(30)
         , @c_OrderInfo09   NVARCHAR(30)  
         , @n_Sum           INT = 0
         , @n_TempNumber    INT = 0
         , @n_LoopCount     INT = 0

   --WL04 END 
   
   --NJOW02
   DECLARE @c_FamiliyOrdUpdMCompany_Opt1 NVARCHAR(10)
          ,@c_Company                    NVARCHAR(45)
   
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   

   --WL02 Start
   IF CURSOR_STATUS('LOCAL' , 'Cur_Order') in (0 , 1)
   BEGIN
      CLOSE Cur_Order
      DEALLOCATE Cur_Order
   END  
   --WL02 End  
            
	 IF @c_Action IN ('INSERT','UPDATE')     --WL01 
	 BEGIN
	    --NJOW02 S
	    SET @c_FamiliyOrdUpdMCompany_Opt1 = 'N'
	    SELECT  @c_FamiliyOrdUpdMCompany_Opt1 = SC.Option1
      FROM dbo.fnc_GetRight2('', @c_Storerkey,'','OrdersTrigger_SP') AS SC       
      --NJOW02 E	    	 
	 	
      DECLARE Cur_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  --WL02
         SELECT DISTINCT I.Orderkey, O.ShipperKey, I.Markforkey
         FROM #INSERTED I
         JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey
         --JOIN CODELKUP C (NOLOCK) ON C.Listname = 'TRACKNO' AND C.Code = I.ShipperKey AND C.Storerkey = I.Storerkey   --WL04
         CROSS APPLY (SELECT TOP 1 Code FROM CODELKUP (NOLOCK)                             --WL04
                      WHERE LISTNAME = 'TRACKNO' AND CODE = I.Shipperkey                   --WL04
                      ORDER BY CASE WHEN Storerkey = I.Storerkey THEN 1 ELSE 2 END) AS C   --WL04
         WHERE I.Storerkey = @c_Storerkey         
         AND I.Shipperkey IN('711','PELICAN','Family')   --WL04

      OPEN Cur_Order
	  
	    FETCH NEXT FROM Cur_Order INTO @c_Orderkey, @c_Shipperkey, @c_MarkforKey

	    WHILE @@FETCH_STATUS <> -1 
	    BEGIN	    
	    	 IF ISNULL(@c_Shipperkey,'') = ''
	    	 BEGIN
	    	 	  SELECT @n_continue = 3, @n_err = 60090, @c_errmsg = 'Order# ' + RTRIM(@c_Orderkey) + '. Empty Shipperkey is not allowed. (ispORD03)' 
	    	 	  GOTO QUIT_SP
	    	 END
	    	 
	    	 SELECT @c_Code = Code, 
	    	        @c_UDF01 = UDF01, --Min number
	    	        @c_UDF02 = UDF02, --Max number
	    	        @c_UDF03 = UDF03, --Current number
	    	        @c_UDF05 = UDF05,
	    	        @n_Len = LEN(RTRIM(@c_UDF01))
	    	 FROM CODELKUP (NOLOCK) 
	    	 WHERE Listname ='TRACKNO'
	    	 AND Code = @c_Shipperkey
	    	 AND Storerkey = @c_Storerkey 
          
	    	 
	    	 --WL04 S
          IF @c_Shipperkey = 'Family'
	    	 BEGIN
	    	    SELECT @c_Code = Code, 
	    	           @c_UDF01 = UDF01, --Min number
	    	           @c_UDF02 = UDF02, --Max number
	    	           @c_UDF03 = UDF03, --Current number
	    	           @c_UDF05 = UDF05,
	    	           @n_Len = LEN(RTRIM(@c_UDF01))
	    	    FROM CODELKUP (NOLOCK) 
	    	    WHERE Listname ='TRACKNO'
	    	    AND Code = @c_Shipperkey
             AND Code2 = DATEPART(YEAR,GETDATE())         --CS01
	    	 END
	    	 --WL04 E
	    	 
	    	 /*IF ISNULL(@c_Code,'') = ''
	    	 BEGIN
	    	 	  SELECT @n_continue = 3, @n_err = 60092, @c_errmsg = 'ASN# ' + RTRIM(@c_Orderkey) + '. Tracking Number configuration not yet setup for ' + RTRIM(@c_Shipperkey) + '. (ispORD03)' 
	    	 	  GOTO QUIT_SP
	    	 END*/
	    	 
	    	 IF ISNUMERIC(@c_UDF01) <>  1 OR ISNUMERIC(@c_UDF02) <>  1 OR @c_UDF01 > @c_UDF02
	    	 BEGIN
	    	 	  SELECT @n_continue = 3, @n_err = 60093, @c_errmsg = 'Order# ' + RTRIM(@c_Orderkey) + '. Invalid Tracking Number range setup for ' + RTRIM(@c_Shipperkey) + '. (ispORD03)' 
	    	 	  GOTO QUIT_SP
	    	 END	    	 
	    	 
	    	 IF NOT EXISTS(SELECT 1 FROM CARTONTRACK(NOLOCK) WHERE KeyName = 'ORDERS' and LabelNo = @c_Orderkey AND CarrierName = @c_Shipperkey)
	    	 BEGIN	    	
	    	    IF ISNUMERIC(@c_UDF03) <> 1	    	    
	    	       SET @c_UDF03 = @c_UDF01
	    	       
	    	    SET @c_UDF03 = RIGHT(REPLICATE('0',@n_Len) + RTRIM(LTRIM(CONVERT(NVARCHAR, CAST(@c_UDF03 AS BIGINT) + 1))), @n_Len)
	    	    
	    	    IF CAST(@c_UDF03 AS BIGINT) > CAST(@c_UDF02 AS BIGINT) 
	    	    BEGIN
	    	    	  SELECT @n_continue = 3, @n_err = 60094, @c_errmsg = 'Order# ' + RTRIM(@c_Orderkey) + '. New Tracking Number ' + RTRIM(@c_UDF03) + ' exceeded limit for ' + RTRIM(@c_Shipperkey) + '. (ispORD03)' 
	    	    	  GOTO QUIT_SP
	    	    END
	    	    
	    	    IF @c_Shipperkey = '711'  --NJOW01
	    	    BEGIN
	    	    	 SELECT @c_CI_Short = Short, 
	    	              @c_CI_UDF02 = UDF02
	    	       FROM CODELKUP (NOLOCK) 
	    	       WHERE Listname ='CARRIERINF'
	    	       AND Code = @c_Shipperkey
	    	       AND Storerkey = @c_Storerkey 
	    	 	
	    	       SET @c_TrackingNo = RTRIM(LTRIM(ISNULL(@c_Markforkey,''))) + RTRIM(LTRIM(ISNULL(@c_CI_Short,''))) + RTRIM(LTRIM(ISNULL(@c_CI_UDF02,''))) + RTRIM(@c_UDF03)
	    	    END
             --WL04 START
             ELSE IF @c_Shipperkey = 'Family'
             BEGIN
                SELECT @c_CI_Short = LTRIM(RTRIM(ISNULL(Short,'')))
                     , @c_CI_UDF01 = LTRIM(RTRIM(ISNULL(UDF01,'')))
                     , @c_CI_UDF02 = LTRIM(RTRIM(ISNULL(UDF02,'')))
                     , @c_CI_UDF03 = LTRIM(RTRIM(ISNULL(Notes,'')))
                     , @c_CI_Long  = LTRIM(RTRIM(ISNULL(Long,'')))
                FROM CODELKUP (NOLOCK) 
                WHERE Listname ='CARRIERINF'
                AND Code = @c_Shipperkey
                AND Storerkey = @c_Storerkey 

                SELECT @c_SUSR1 = LTRIM(RTRIM(ISNULL(ST.SUSR1,'')))
                     , @c_SUSR2 = LTRIM(RTRIM(ISNULL(ST.SUSR2,'')))
                     , @c_SUSR3 = LTRIM(RTRIM(ISNULL(ST.SUSR3,'')))    
                FROM STORER ST (NOLOCK)
                WHERE ST.B_Company = ISNULL(@c_MarkforKey,'')
                AND ST.ConsigneeFor = 'Family'

                --Get Check Digit for Orders.M_VAT
                IF (@n_Continue = 1 OR @n_Continue = 2)
                BEGIN 
                   SELECT @c_GetSec = '1' + LTRIM(RTRIM(ISNULL(@c_CI_Short,''))) + '00' + LTRIM(RTRIM(ISNULL(@c_UDF03,'')))
                   
                   WHILE (LEN(@c_GetSec) > 0 AND ISNUMERIC(@c_GetSec) = 1)
                   BEGIN
                      SET @n_TempNumber = CAST(LEFT(@c_GetSec,1) AS INT)
                      
                      IF @n_Sum = 0
                      BEGIN
                         SET @n_Sum = @n_TempNumber
                      END
                      ELSE
                      BEGIN
                         SET @n_Sum = @n_Sum + @n_TempNumber
                      END
                      
                      SET @c_GetSec = RIGHT(@c_GetSec, LEN(@c_GetSec) - 1)
                      SET @n_LoopCount = @n_LoopCount + 1
                      
                      IF @n_LoopCount >= 20
                         BREAK;
                   END
    
                   IF @n_Sum % 43 = 0 SET @c_GetCheckC = '0'  
                   ELSE IF @n_Sum % 43 = 1  SET @c_GetCheckC = '1'  
                   ELSE IF @n_Sum % 43 = 2  SET @c_GetCheckC = '2'  
                   ELSE IF @n_Sum % 43 = 3  SET @c_GetCheckC = '3'  
                   ELSE IF @n_Sum % 43 = 4  SET @c_GetCheckC = '4'  
                   ELSE IF @n_Sum % 43 = 5  SET @c_GetCheckC = '5'  
                   ELSE IF @n_Sum % 43 = 6  SET @c_GetCheckC = '6'  
                   ELSE IF @n_Sum % 43 = 7  SET @c_GetCheckC = '7'  
                   ELSE IF @n_Sum % 43 = 8  SET @c_GetCheckC = '8'  
                   ELSE IF @n_Sum % 43 = 9  SET @c_GetCheckC = '9'  
                   ELSE IF @n_Sum % 43 = 10 SET @c_GetCheckC = 'A'  
                   ELSE IF @n_Sum % 43 = 11 SET @c_GetCheckC = 'B'  
                   ELSE IF @n_Sum % 43 = 12 SET @c_GetCheckC = 'C'  
                   ELSE IF @n_Sum % 43 = 13 SET @c_GetCheckC = 'D'  
                   ELSE IF @n_Sum % 43 = 14 SET @c_GetCheckC = 'E'  
                   ELSE IF @n_Sum % 43 = 15 SET @c_GetCheckC = 'F'  
                   ELSE IF @n_Sum % 43 = 16 SET @c_GetCheckC = 'G'  
                   ELSE IF @n_Sum % 43 = 17 SET @c_GetCheckC = 'H'  
                   ELSE IF @n_Sum % 43 = 18 SET @c_GetCheckC = 'I'  
                   ELSE IF @n_Sum % 43 = 19 SET @c_GetCheckC = 'J'  
                   ELSE IF @n_Sum % 43 = 20 SET @c_GetCheckC = 'K'  
                   ELSE IF @n_Sum % 43 = 21 SET @c_GetCheckC = 'L'  
                   ELSE IF @n_Sum % 43 = 22 SET @c_GetCheckC = 'M'  
                   ELSE IF @n_Sum % 43 = 23 SET @c_GetCheckC = 'N'  
                   ELSE IF @n_Sum % 43 = 24 SET @c_GetCheckC = 'O'  
                   ELSE IF @n_Sum % 43 = 25 SET @c_GetCheckC = 'P'  
                   ELSE IF @n_Sum % 43 = 26 SET @c_GetCheckC = 'Q'  
                   ELSE IF @n_Sum % 43 = 27 SET @c_GetCheckC = 'R'  
                   ELSE IF @n_Sum % 43 = 28 SET @c_GetCheckC = 'S'  
                   ELSE IF @n_Sum % 43 = 29 SET @c_GetCheckC = 'T'  
                   ELSE IF @n_Sum % 43 = 30 SET @c_GetCheckC = 'U'  
                   ELSE IF @n_Sum % 43 = 31 SET @c_GetCheckC = 'V'  
                   ELSE IF @n_Sum % 43 = 32 SET @c_GetCheckC = 'W'  
                   ELSE IF @n_Sum % 43 = 33 SET @c_GetCheckC = 'X'  
                   ELSE IF @n_Sum % 43 = 34 SET @c_GetCheckC = 'Y'  
                   ELSE IF @n_Sum % 43 = 35 SET @c_GetCheckC = 'Z'  
                   ELSE IF @n_Sum % 43 = 36 SET @c_GetCheckC = '-'  
                   ELSE IF @n_Sum % 43 = 37 SET @c_GetCheckC = '.'  
                   ELSE IF @n_Sum % 43 = 38 SET @c_GetCheckC = ' '  
                   ELSE IF @n_Sum % 43 = 39 SET @c_GetCheckC = '$'  
                   ELSE IF @n_Sum % 43 = 40 SET @c_GetCheckC = '/'  
                   ELSE IF @n_Sum % 43 = 41 SET @c_GetCheckC = '+'  
                   ELSE IF @n_Sum % 43 = 42 SET @c_GetCheckC = '%'  
                   
                   SELECT @c_M_VAT = SUBSTRING('1' + LTRIM(RTRIM(ISNULL(@c_CI_Short,''))) + '00' + LTRIM(RTRIM(ISNULL(@c_UDF03,''))) + @c_GetCheckC,1,18)
                END--Get Check Digit for Orders.M_VAT End
                
                SET @c_TrackingNo = LTRIM(RTRIM(ISNULL(@c_UDF03,'')))
             END
             --WL04 END
	    	    ELSE
	    	    BEGIN
	    	       SET @c_TrackingNo = RIGHT(REPLICATE('0',@n_Len) + RTRIM(LTRIM(CONVERT(NVARCHAR,(CAST(@c_UDF03 AS BIGINT) * 10)+(CAST(@c_UDF03 AS BIGINT) % 7)))), @n_Len + 1)  --add check digit
	    	    END
	    	    
	    	    INSERT INTO CARTONTRACK (LabelNo, CarrierName, KeyName, TrackingNo, UDF03)
	    	    VALUES (@c_Orderkey, @c_Shipperkey, 'ORDERS', @c_TrackingNo, @c_UDF05)
	    	    
	    	    --WL04 S
             IF @c_Shipperkey = 'Family'
	    	    BEGIN
	    	       UPDATE CODELKUP WITH (ROWLOCK)
                SET UDF03 = @c_UDF03
                WHERE Listname ='TRACKNO'
                AND Code = @c_Shipperkey
	    	    END
	    	    ELSE
	    	    BEGIN
                UPDATE CODELKUP WITH (ROWLOCK)
                SET UDF03 = @c_UDF03
                WHERE Listname ='TRACKNO'
                AND Code = @c_Shipperkey 
                AND Storerkey = @c_Storerkey	   
	    	    END
	    	    --WL04 E

	    	    --WL01 START
	    	    IF @c_Shipperkey = 'Family'
	    	    BEGIN
                UPDATE ORDERS WITH (ROWLOCK)
                SET TrackingNo   = @c_TrackingNo,
                    M_Contact2   = SUBSTRING(@c_TrackingNo,1,30),
                    M_Address3   = SUBSTRING(@c_CI_Short,1,18) + @c_Orderkey,
                    M_Fax1       = SUBSTRING(@c_CI_Short,1,18),
                    M_Fax2       = SUBSTRING(@c_CI_UDF02,1,18),
                    [Route]      = SUBSTRING(@c_SUSR1,1,10),
                    M_Zip        = SUBSTRING(@c_CI_UDF03,1,18),
                    M_Country    = SUBSTRING(@c_CI_Long,1,30),
                    M_VAT        = @c_M_VAT,
                    M_Company    = CASE WHEN LEFT(LTRIM(RTRIM(ISNULL(M_Company,''))), 2) <> N'全家' AND ISNULL(M_Company,'') <> ''
                                        THEN N'全家' + LTRIM(RTRIM(ISNULL(M_Company,'')))
                                        ELSE M_Company END,
                    Userdefine10 = @c_UDF05,
                    TrafficCop   = NULL
                WHERE OrderKey = @c_Orderkey	 

                --Debug
                --INSERT INTO TraceInfo (TraceName, TimeIn, [TimeOut], Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
                --SELECT 'ispORD03_OH1',GETDATE(), GETDATE(),'TrackingNo','M_Contact2','M_Address3','M_Fax1','M_Fax2', @c_TrackingNo,SUBSTRING(@c_TrackingNo,1,30),@c_Orderkey,SUBSTRING(@c_CI_Short,1,18),SUBSTRING(@c_CI_UDF02,1,18)
                
                --INSERT INTO TraceInfo (TraceName, TimeIn, [TimeOut], Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
                --SELECT 'ispORD03_OH2',GETDATE(), GETDATE(),'[Route]','M_Zip','M_Country','M_VAT','Userdefine10', SUBSTRING(@c_SUSR1,1,10),SUBSTRING(@c_CI_UDF03,1,18),SUBSTRING(@c_CI_Long,1,30),@c_M_VAT,@c_UDF05
                
	    	    END
	    	    ELSE
	    	    BEGIN
	    	       UPDATE ORDERS WITH (ROWLOCK)
	    	       SET TrackingNo = @c_TrackingNo,
	    	           Userdefine10 = @c_UDF05,   --WL03
	    	           TrafficCop = NULL
	    	       WHERE OrderKey = @c_Orderkey	 
	    	    END   
	    	    --WL01 END	   
	    	 END
	    	 --WL04 S
	    	 BEGIN
             IF EXISTS (SELECT 1 FROM ORDERINFO (NOLOCK) WHERE Orderkey = @c_Orderkey) AND @c_Shipperkey = 'Family'   --For Update Orderinfo
             BEGIN
                SELECT @c_UDF03      = TrackingNo
                     , @c_MarkforKey = MarkforKey
                FROM ORDERS (NOLOCK)
                WHERE OrderKey = @c_Orderkey
                
                SELECT @c_CI_Short    = LTRIM(RTRIM(ISNULL(Short,'')))
                     , @c_CI_UDF01    = LTRIM(RTRIM(ISNULL(UDF01,'')))
                     , @c_OrderInfo07 = 'DRE'--LTRIM(RTRIM(ISNULL(Code2,'')))    --CS01
                FROM CODELKUP (NOLOCK) 
                WHERE Listname ='CARRIERINF'
                AND Code = @c_Shipperkey
                AND Storerkey = @c_Storerkey 
                
                SELECT @c_SUSR2 = LEFT(LTRIM(RTRIM(ISNULL(ST.SUSR2,''))), 2) + RIGHT(LTRIM(RTRIM(ISNULL(ST.SUSR2,''))), 2)
                     , @c_SUSR3 = LTRIM(RTRIM(ISNULL(ST.SUSR3,'')))
                FROM STORER ST (NOLOCK)
                WHERE ST.B_Company = ISNULL(@c_MarkforKey,'')
                AND ST.ConsigneeFor = 'Family'
                
                --Get Check Digit for Orderinfo.OrderInfo09
                IF (@n_Continue = 1 OR @n_Continue = 2)
                BEGIN
                   SELECT @c_GetCheckASec1 = LTRIM(RTRIM(ISNULL(@c_CI_Short,''))) + SUBSTRING(LTRIM(RTRIM(ISNULL(@c_UDF03,''))),1,3) + LTRIM(RTRIM(ISNULL(@c_CI_UDF01,'')))
                   SELECT @c_GetCheckASec2 = SUBSTRING(LTRIM(RTRIM(ISNULL(@c_UDF03,''))),4,8) + 
                                             CASE WHEN OIF.OrderInfo03 = 'Y' THEN '1' ELSE '3' END + 
                                             RIGHT('00000' + CAST(OIF.PayableAmount AS NVARCHAR(5)), 5)
                   From ORDERS OH (NOLOCK)  
                   JOIN ORDERINFO OIF (NOLOCK) ON OH.Orderkey = OIF.Orderkey  
                   WHERE OH.Orderkey = @c_Orderkey   
                   
                   --SELECT @c_GetCheckASec1,@c_GetCheckASec2
                   
                   SET @n_Sec1a = CONVERT(INT,SUBSTRING(@c_GetCheckASec1,1,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckASec1,3,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckASec1,5,1))
                                + CONVERT(INT,SUBSTRING(@c_GetCheckASec1,7,1))+ CONVERT(INT,SUBSTRING(@c_GetCheckASec1,9,1)) --+ CONVERT(INT,SUBSTRING(@c_GetCheckASec1,11,1))
                                --+ CONVERT(INT,SUBSTRING(@c_GetCheckASec1,13,1))  
                       
                   SET @n_Sec1b = CONVERT(INT,SUBSTRING(@c_GetCheckASec2,1,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckASec2,3,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckASec2,5,1))
                                + CONVERT(INT,SUBSTRING(@c_GetCheckASec2,7,1))+ CONVERT(INT,SUBSTRING(@c_GetCheckASec2,9,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckASec2,11,1)) 
                                + CONVERT(INT,SUBSTRING(@c_GetCheckASec2,13,1))  
                   
                   SET @n_Sec1 = (@n_Sec1a + @n_Sec1b)
                   
                   IF @n_Sec1 % 11 = 0
                   BEGIN
                      SET @c_GetCheckA = '0'
                   END
                   ELSE IF @n_Sec1 % 11 = 10
                   BEGIN
                      SET @c_GetCheckA = '1'
                   END
                   ELSE
                   BEGIN
                      SET @c_GetCheckA = @n_Sec1 % 11
                   END   
                   --SELECT @c_GetCheckA
                   
                   SELECT @c_GetCheckBSec1 = @c_GetCheckASec1
                   SELECT @c_GetCheckBSec2 = @c_GetCheckASec2
                    
                   SET @n_Sec2a = CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,2,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,4,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,6,1))
                                + CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,8,1)) --+ CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,10,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,12,1))
                                --+ CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,14,1))
                   SET @n_Sec2b = CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,2,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,4,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,6,1))
                                + CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,8,1))+ CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,10,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,12,1))
                                + CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,14,1))
                
                   SET @n_Sec2 = (@n_Sec2a + @n_Sec2b)
                
                   IF @n_Sec2 % 11 = 0
                   BEGIN
                      SET @c_GetCheckB = '8'
                   END
                   ELSE IF @n_Sec2 % 11 = 10
                   BEGIN
                      SET @c_GetCheckB = '9'
                   END
                   ELSE
                   BEGIN
                      SET @c_GetCheckB = @n_Sec2 % 11
                   END   
                   
                   SELECT @c_OrderInfo09 =  SUBSTRING(LTRIM(RTRIM(@c_GetCheckASec2)) + @c_GetCheckA +@c_GetCheckB,1,30)
                END   --Get Check Digit for Orderinfo.OrderInfo09 End
                
                --Get Check Digit for Orderinfo.OrderInfo08
                IF (@n_Continue = 1 OR @n_Continue = 2)
                BEGIN
                	SELECT @c_OrderInfo08 = LTRIM(RTRIM(ISNULL(@c_CI_Short,''))) + SUBSTRING(LTRIM(RTRIM(ISNULL(@c_UDF03,''))),1,3) + LTRIM(RTRIM(ISNULL(@c_CI_UDF01,'')))
                END
                --Get Check Digit for Orderinfo.OrderInfo08
                
                --IF (@n_Continue = 1 OR @n_Continue = 2)
                --BEGIN
                   --SELECT @c_GetCheckBSec1 = @c_GetCheckASec1
                   --SELECT @c_GetCheckBSec2 = @c_GetCheckASec2
                    
                   --SET @n_Sec2a = CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,2,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,4,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,6,1))
                   --             + CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,8,1))+ CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,10,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,12,1))
                   --             + CONVERT(INT,SUBSTRING(@c_GetCheckBSec1,14,1))
                   --SET @n_Sec2b = CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,2,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,4,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,6,1))
                   --             + CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,8,1))+ CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,10,1)) + CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,12,1))
                   --             + CONVERT(INT,SUBSTRING(@c_GetCheckBSec2,14,1))
                
                   --SET @n_Sec2 = (@n_Sec2a + @n_Sec2b)
                
                   --IF @n_Sec2 % 11 = 0
                   --BEGIN
                   --   SET @c_GetCheckB = '8'
                   --END
                   --ELSE IF @n_Sec2 % 11 = 10
                   --BEGIN
                   --   SET @c_GetCheckB = '9'
                   --END
                   --ELSE
                   --BEGIN
                   --   SET @c_GetCheckB = @n_Sec2 % 11
                   --END   
                
                --   SELECT @c_OrderInfo09 =  SUBSTRING(LTRIM(RTRIM(@c_GetCheckBSec2)) + @c_GetCheckB,1,30)
                --END   --Get Check Digit for Orderinfo.OrderInfo08 End
                
	    	       UPDATE ORDERINFO WITH (ROWLOCK)
                SET OrderInfo07      = SUBSTRING(@c_OrderInfo07,1,30),
                    OrderInfo08      = @c_OrderInfo08,
                    OrderInfo09      = @c_OrderInfo09,
                    DeliveryCategory = @c_SUSR2,
                    OrderInfo10      = @c_SUSR3,
                    TrafficCop   = NULL
                WHERE OrderKey = @c_Orderkey	
             
                SET @c_UDF05 = @@ROWCOUNT
             
                --INSERT INTO TraceInfo (TraceName, TimeIn, [TimeOut], Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
                --SELECT 'ispORD03_OIF2',GETDATE(), GETDATE(),'OrderInfo07','OrderInfo08','OrderInfo09','ROWCOUNT','Orderkey', OIF.OrderInfo07,OIF.OrderInfo08,OIF.OrderInfo09,@c_UDF05,@c_Orderkey
                --FROM ORDERINFO OIF (NOLOCK)
                --WHERE OIF.OrderKey = @c_Orderkey
             
                --Debug
                --INSERT INTO TraceInfo (TraceName, TimeIn, [TimeOut], Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
                --SELECT 'ispORD03_OIF',GETDATE(), GETDATE(),'OrderInfo07','OrderInfo08','OrderInfo09','DeliveryCategory','Orderkey', SUBSTRING(@c_CI_Short,1,30),@c_OrderInfo08,@c_OrderInfo09,@c_SUSR2,@c_Orderkey
             END
          END
	    	 --WL04 E
	    	 
	    	 --NJOW02 S
	    	 IF @c_FamiliyOrdUpdMCompany_Opt1 = 'Y'
	    	 BEGIN
	    	 	   SET @c_Company = ''
	    	 	   
	    	 	   SELECT @c_Company = ST.Company
	    	 	   FROM STORER ST (NOLOCK)
             WHERE ST.B_Company = ISNULL(@c_MarkforKey,'')
             AND ST.ConsigneeFor = 'Family'
             
             IF ISNULL(@c_Company,'') <> ''
             BEGIN
	    	        UPDATE ORDERS WITH (ROWLOCK)
                SET M_Company = @c_Company,
                    TrafficCop   = NULL
                WHERE OrderKey = @c_Orderkey	             	  
             END
	    	 END
	    	 --NJOW02 E
	    		    		    	
         FETCH NEXT FROM Cur_Order INTO @c_Orderkey, @c_Shipperkey, @c_MarkforKey
	    END
   END
      
   QUIT_SP:
   IF CURSOR_STATUS('LOCAL' , 'Cur_Order') in (0 , 1)          --WL02
   BEGIN
      CLOSE Cur_Order
      DEALLOCATE Cur_Order
   END    
   
	 IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @b_Success = 0
	    IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
	    BEGIN
	    	ROLLBACK TRAN
	    END
	    ELSE
	    BEGIN
	    	WHILE @@TRANCOUNT > @n_StartTCnt
	    	BEGIN
	    		COMMIT TRAN
	    	END
	    END
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD03'		
	    --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @b_Success = 1
	    WHILE @@TRANCOUNT > @n_StartTCnt
	    BEGIN
	    	COMMIT TRAN
	    END
	    RETURN
	 END  
END  

GO