SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Function:   isp_Return_Note03_rdt                                    */
/* Creation Date: 02-FEB-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-16045 - [KR] - iiCombined - Return Notes in English     */
/*                                                                      */
/* Called By:  r_dw_return_note03_rdt                                   */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 03-JAN-2023  CSCHONG   1.1   Devops Scripts Combine & WMS-21392 (CS01)*/
/* 09-MAR-2023  CSCHONG   1.2   WMS-21876 add new field (CS02)           */
/* 18-APR-2023  WZPANG    1.3   WMS-22268 Modify group by part of       */
/*                                        PACKDETAIL                    */
/************************************************************************/

CREATE   PROC [dbo].[isp_Return_Note03_rdt]  (
    @c_Orderkey           NVARCHAR(10)
   ,@c_C_ISOCntryCode     NVARCHAR(20) = ''
   ,@c_Facility           NVARCHAR(10) = ''
   ,@c_Type               NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_InvAmt             FLOAT
         , @n_ShippingHandling   FLOAT
         , @n_NoOfLine           INT
         , @c_Country            NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)

   DECLARE  @n_MaxLineno       INT
         , @n_MaxId           INT
         , @n_MaxRec          INT
         , @n_CurrentRec      INT

   SET @n_MaxLineno = 10           --CS01

   SELECT @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE OrderKey = @c_Orderkey

   DECLARE @c_A2  NVARCHAR(250) = ''
         , @c_A3  NVARCHAR(250) = ''
         , @c_A4  NVARCHAR(250) = ''
         , @c_A5  NVARCHAR(250) = ''
         , @c_A6  NVARCHAR(250) = ''
         , @c_A7  NVARCHAR(250) = ''
         , @c_A8  NVARCHAR(250) = ''
         , @c_A9  NVARCHAR(250) = ''
         , @c_A10 NVARCHAR(250) = ''
         , @c_A11 NVARCHAR(250) = ''
         , @c_A12 NVARCHAR(250) = ''
         , @c_A13 NVARCHAR(250) = ''
         , @c_A14 NVARCHAR(250) = ''

--CS01 S
   DECLARE @c_A1573   NVARCHAR(250) = ''
         , @c_A1574   NVARCHAR(250) = ''
         , @c_A1575   NVARCHAR(250) = ''
         , @c_A1576   NVARCHAR(250) = ''
         , @c_A158    NVARCHAR(250) = ''
         , @c_A159    NVARCHAR(250) = ''
         , @c_A161    NVARCHAR(250) = ''
         , @c_A162    NVARCHAR(250) = ''
         , @c_A163    NVARCHAR(250) = ''
         , @c_A164    NVARCHAR(250) = ''
         , @c_A165    NVARCHAR(250) = ''
         , @c_A166    NVARCHAR(250) = ''
         , @c_A167    NVARCHAR(250) = ''
         , @c_A168    NVARCHAR(250) = ''
         , @c_A171    NVARCHAR(250) = ''
         , @c_A172    NVARCHAR(250) = ''
         , @c_A173    NVARCHAR(250) = ''
         , @c_A174    NVARCHAR(250) = ''
         , @c_A175    NVARCHAR(250) = ''
         , @c_A176    NVARCHAR(250) = ''
         , @c_A177    NVARCHAR(250) = ''
         , @c_A178    NVARCHAR(250) = ''
         , @c_A181    NVARCHAR(250) = ''
         , @c_A182    NVARCHAR(250) = ''
         , @c_A183    NVARCHAR(250) = ''
         , @c_A184    NVARCHAR(250) = ''
         , @c_A152    NVARCHAR(250) = ''
         , @c_A153    NVARCHAR(250) = ''
         , @c_A154    NVARCHAR(250) = ''
         , @c_A155    NVARCHAR(250) = ''
         , @c_A156    NVARCHAR(250) = ''
         , @c_A1571   NVARCHAR(250) = ''
         , @c_A1572   NVARCHAR(250) = ''
         , @c_A151    NVARCHAR(250) = ''
--CS01 E

--CS02 S
         , @c_A20     NVARCHAR(250) = ''
         , @c_A21     NVARCHAR(250) = ''
         , @c_A169    NVARCHAR(250) = ''
         , @c_A170    NVARCHAR(250) = ''
         , @c_A179    NVARCHAR(250) = ''
         , @c_A180    NVARCHAR(250) = ''
--CS02 E

--   SELECT @c_A2  = ISNULL(MAX(CASE WHEN C.Code ='A2'  THEN RTRIM(C.long) ELSE 'RETURNS REQUEST' END),'')
--        , @c_A3  = ISNULL(MAX(CASE WHEN C.Code ='A3'  THEN RTRIM(C.long) ELSE 'FROM' END),'')
--        , @c_A4  = ISNULL(MAX(CASE WHEN C.Code ='A4'  THEN RTRIM(C.long) ELSE 'ORDER NUMBER' END),'')
--        , @c_A5  = ISNULL(MAX(CASE WHEN C.Code ='A5'  THEN RTRIM(C.long) ELSE 'SHIP TO' END),'')
--        , @c_A6  = ISNULL(MAX(CASE WHEN C.Code ='A6'  THEN RTRIM(C.long) ELSE 'PAYMENT DETAILS' END),'')
--        , @c_A7  = ISNULL(MAX(CASE WHEN C.Code ='A7'  THEN RTRIM(C.long) ELSE 'SHIPPING METHOD' END),'')
--        , @c_A8  = ISNULL(MAX(CASE WHEN C.Code ='A8'  THEN RTRIM(C.long) ELSE 'SHIPPING DATE' END),'')
--        , @c_A9  = ISNULL(MAX(CASE WHEN C.Code ='A9'  THEN RTRIM(C.long) ELSE 'QTY' END),'')
--        , @c_A10 = ISNULL(MAX(CASE WHEN C.Code ='A10' THEN RTRIM(C.long) ELSE 'PRODUCT' END),'')
--        , @c_A11 = ISNULL(MAX(CASE WHEN C.Code ='A11' THEN RTRIM(C.long) ELSE 'RETURN QTY' END),'')
--        , @c_A12 = ISNULL(MAX(CASE WHEN C.Code ='A12' THEN RTRIM(C.long) ELSE '*RETURN REASON' END),'')
--        , @c_A13 = ISNULL(MAX(CASE WHEN C.Code ='A13' THEN RTRIM(C.long) ELSE 'HOW TO RETURN' END),'')
--        , @c_A14 = ISNULL(MAX(CASE WHEN C.Code ='A14' THEN RTRIM(C.long) ELSE '*RETURN REASON' END),'')
----CS01 S
--         , @c_A1573  = ISNULL(MAX(CASE WHEN C.Code ='A1573' THEN RTRIM(C.long) ELSE 'Ã² City: Yongin-si' END),'')
--         , @c_A1574  = ISNULL(MAX(CASE WHEN C.Code ='A1574' THEN RTRIM(C.long) ELSE 'Ã² Province: Gyeonggi-do' END),'')
--         , @c_A1575  = ISNULL(MAX(CASE WHEN C.Code ='A1575' THEN RTRIM(C.long) ELSE 'Ã² Country: Republic of Korea' END),'')
--         , @c_A1576  = ISNULL(MAX(CASE WHEN C.Code ='A1576' THEN RTRIM(C.long) ELSE 'Ã² Postcode: 17172' END),'')
--         , @c_A158   = ISNULL(MAX(CASE WHEN C.Code ='A158' THEN RTRIM(C.long) ELSE 'Once your package arrives at our warehouse, you will get a refund into your ' END),'')
--         , @c_A159   = ISNULL(MAX(CASE WHEN C.Code ='A159' THEN RTRIM(C.long) ELSE 'original payment method after return inspection completed.' END),'')
--         , @c_A161   = ISNULL(MAX(CASE WHEN C.Code ='A161' THEN RTRIM(C.long) ELSE 'In store purchase' END),'')
--         , @c_A162   = ISNULL(MAX(CASE WHEN C.Code ='A162' THEN RTRIM(C.long) ELSE 'Damaged or defective' END),'')
--         , @c_A163   = ISNULL(MAX(CASE WHEN C.Code ='A163' THEN RTRIM(C.long) ELSE 'Purchased other products' END),'')
--         , @c_A164   = ISNULL(MAX(CASE WHEN C.Code ='A164' THEN RTRIM(C.long) ELSE 'Fit (loose / tight)' END),'')
--         , @c_A165   = ISNULL(MAX(CASE WHEN C.Code ='A165' THEN RTRIM(C.long) ELSE 'Frame (big / small)' END),'')
--         , @c_A166   = ISNULL(MAX(CASE WHEN C.Code ='A166' THEN RTRIM(C.long) ELSE 'TOO HEAVY' END),'')
--         , @c_A167   = ISNULL(MAX(CASE WHEN C.Code ='A167' THEN RTRIM(C.long) ELSE 'WRONG DELIVERY' END),'')
--         , @c_A168   = ISNULL(MAX(CASE WHEN C.Code ='A168' THEN RTRIM(C.long) ELSE 'MISSING COMPONENT' END),'')
--         , @c_A171   = ISNULL(MAX(CASE WHEN C.Code ='A171' THEN RTRIM(C.long) ELSE '1' END),'')
--         , @c_A172   = ISNULL(MAX(CASE WHEN C.Code ='A172' THEN RTRIM(C.long) ELSE '2' END),'')
--         , @c_A173   = ISNULL(MAX(CASE WHEN C.Code ='A173' THEN RTRIM(C.long) ELSE '3' END),'')
--         , @c_A174   = ISNULL(MAX(CASE WHEN C.Code ='A174' THEN RTRIM(C.long) ELSE '4' END),'')
--         , @c_A175   = ISNULL(MAX(CASE WHEN C.Code ='A175' THEN RTRIM(C.long) ELSE '5' END),'')
--         , @c_A176   = ISNULL(MAX(CASE WHEN C.Code ='A176' THEN RTRIM(C.long) ELSE '6' END),'')
--         , @c_A177   = ISNULL(MAX(CASE WHEN C.Code ='A177' THEN RTRIM(C.long) ELSE '7' END),'')
--         , @c_A178   = ISNULL(MAX(CASE WHEN C.Code ='A178' THEN RTRIM(C.long) ELSE '8' END),'')
--         , @c_A181   = ISNULL(MAX(CASE WHEN C.Code ='A181' THEN RTRIM(C.long) ELSE 'GENTLE MONSTER' END),'')
--         , @c_A182   = ISNULL(MAX(CASE WHEN C.Code ='A182' THEN RTRIM(C.long) ELSE '434, Gachang-ri, Baegam-myeon, Cheoin-gu' END),'')
--         , @c_A183   = ISNULL(MAX(CASE WHEN C.Code ='A183' THEN RTRIM(C.long) ELSE 'Yongin-si, Gyeonggi-do, 17172,' END),'')
--         , @c_A184   = ISNULL(MAX(CASE WHEN C.Code ='A184' THEN RTRIM(C.long) ELSE 'Republic of Korea' END),'')
--         , @c_A152   = ISNULL(MAX(CASE WHEN C.Code ='A152' THEN RTRIM(C.long) ELSE 'on the Gentle Monster website.' END),'')
--         , @c_A153   = ISNULL(MAX(CASE WHEN C.Code ='A153' THEN RTRIM(C.long) ELSE 'Please arrange return your parcel to our warehouse, the return shipping must ' END),'')
--         , @c_A154   = ISNULL(MAX(CASE WHEN C.Code ='A154' THEN RTRIM(C.long) ELSE 'be paid by customerÃ†s end. You can use any courier but, DHL is preferable' END),'')
--         , @c_A155   = ISNULL(MAX(CASE WHEN C.Code ='A155' THEN RTRIM(C.long) ELSE 'Please pack the item securely with all its belongings and enclose this RETURN REQUEST.' END),'')
--         , @c_A156   = ISNULL(MAX(CASE WHEN C.Code ='A156' THEN RTRIM(C.long) ELSE 'Please send parcel to our warehouse:' END),'')
--         , @c_A1571  = ISNULL(MAX(CASE WHEN C.Code ='A1571' THEN RTRIM(C.long) ELSE 'Ã² Street: Deokpyeong-ro, Kendall square 3F 8Dock, 120' END),'')
--         , @c_A1572  = ISNULL(MAX(CASE WHEN C.Code ='A1572' THEN RTRIM(C.long) ELSE 'Ã² Town: Baegam-myeon, Cheoin-gu' END),'')
--         , @c_A151   = ISNULL(MAX(CASE WHEN C.Code ='A151' THEN RTRIM(C.long) ELSE 'Please submit RETURN REQUEST at [Account > Order > View Order Details] ' END),'')
----CS01 E
----CS02 S
--         , @c_A20    = ISNULL(MAX(CASE WHEN C.Code ='A20' THEN RTRIM(C.long) ELSE 'Please note that uneven frames are not considered as defectives' END),'')
--         , @c_A21    = ISNULL(MAX(CASE WHEN C.Code ='A21' THEN RTRIM(C.long) ELSE 'due to the nature of material.' END),'')
--         , @c_A169   = ISNULL(MAX(CASE WHEN C.Code ='A169' THEN RTRIM(C.long) ELSE 'Not as pictured / described' END),'')
--         , @c_A170   = ISNULL(MAX(CASE WHEN C.Code ='A170' THEN RTRIM(C.long) ELSE 'OTHER' END),'')
--         , @c_A179   = ISNULL(MAX(CASE WHEN C.Code ='A179' THEN RTRIM(C.long) ELSE '9' END),'')
--         , @c_A180   = ISNULL(MAX(CASE WHEN C.Code ='A180' THEN RTRIM(C.long) ELSE '10' END),'')

----Cs02 E
--   FROM CODELKUP C WITH (NOLOCK)
--   WHERE C.listname = 'RTNENCONST'
--  -- AND C.UDF01 = @c_C_ISOCntryCode    --CS01 E
--   AND C.UDF02 = @c_Facility
--   AND C.storerkey = @c_Storerkey

   CREATE TABLE #TMP_RDTNOTE03RDT                                         
         (  SeqNo                INT IDENTITY (1,1)                    
         ,  RecGroup             INT                                   
         ,  Orderkey             NVARCHAR(10)                          
         ,  Sku                  NVARCHAR(20)                          
         ,  Descr                NVARCHAR(250)                         
         ,  ExtOrderkey          NVARCHAR(50)                          
         ,  Company              NVARCHAR(45)                          
         ,  OrderDate            DATETIME                              
         ,  OHUDF02              NVARCHAR(20)                          
         ,  OHUDF05              NVARCHAR(20)                          
         ,  C_Address1           NVARCHAR(45)                          
         ,  A2                   NVARCHAR(250)                         
         ,  A3                   NVARCHAR(250)                         
         ,  A4                   NVARCHAR(250)                         
         ,  A5                   NVARCHAR(250)                         
         ,  A6                   NVARCHAR(250)                         
         ,  A7                   NVARCHAR(250)                         
         ,  A8                   NVARCHAR(250)                         
         ,  A9                   NVARCHAR(250)                         
         ,  A10                  NVARCHAR(250)                         
         ,  A11                  NVARCHAR(250)                         
         ,  A12                  NVARCHAR(250)                         
         ,  A13                  NVARCHAR(250)                         
         ,  A14                  NVARCHAR(250)                         
         ,  Qty                  INT                                   
         ,  QtyUnit              NVARCHAR(5)                           
         ,  C_Address2           NVARCHAR(45)                          
         ,  C_Address3           NVARCHAR(45)                          
         ,  C_Address4           NVARCHAR(45)                          
         ,  C_Zip                NVARCHAR(45)                          
         ,  A1573                NVARCHAR(250)    --CS01 S                     
         ,  A1574                NVARCHAR(250)                         
         ,  A1575                NVARCHAR(250)                         
         ,  A1576                NVARCHAR(250)                         
         ,  A158                 NVARCHAR(250)                         
         ,  A159                 NVARCHAR(250)                         
         ,  A161                 NVARCHAR(250)                         
         ,  A162                 NVARCHAR(250)                         
         ,  A163                 NVARCHAR(250)                         
         ,  A164                 NVARCHAR(250)                         
         ,  A165                 NVARCHAR(250)                         
         ,  A166                 NVARCHAR(250)                         
         ,  A167                 NVARCHAR(250)                         
         ,  A168                 NVARCHAR(250)                         
         ,  A171                 NVARCHAR(250)                         
         ,  A172                 NVARCHAR(250)                         
         ,  A173                 NVARCHAR(250)                         
         ,  A174                 NVARCHAR(250)                         
         ,  A175                 NVARCHAR(250)                         
         ,  A176                 NVARCHAR(250)                         
         ,  A177                 NVARCHAR(250)                         
         ,  A178                 NVARCHAR(250)                         
         ,  A181                 NVARCHAR(250)                         
         ,  A182                 NVARCHAR(250)                         
         ,  A183                 NVARCHAR(250)                         
         ,  A184                 NVARCHAR(250)                         
         ,  A152                 NVARCHAR(250)                         
         ,  A153                 NVARCHAR(250)                         
         ,  A154                 NVARCHAR(250)                         
         ,  A155                 NVARCHAR(250)                         
         ,  A156                 NVARCHAR(250)                         
         ,  A1571                NVARCHAR(250)                         
         ,  A1572                NVARCHAR(250)                         
         ,  A151                 NVARCHAR(250)       
         ,  C_country            NVARCHAR(45)
         ,  C_state              NVARCHAR(45)
         ,  CountryOfOrigin      NVARCHAR(30)   
         ,  A20                  NVARCHAR(250)       --CS02 S                   
         ,  A21                  NVARCHAR(250)
         ,  A169                 NVARCHAR(250)                         
         ,  A170                 NVARCHAR(250) 
         ,  A179                 NVARCHAR(250)                         
         ,  A180                 NVARCHAR(250)       --CS02 E
         )

   INSERT INTO #TMP_RDTNOTE03RDT
         (  recgroup
         ,  Orderkey
         ,  Sku
         ,  Descr
         ,  ExtOrderkey
         ,  Company
         ,  OrderDate
         ,  OHUDF02
         ,  OHUDF05
         ,  C_Address1
         ,  A2
         ,  A3
         ,  A4
         ,  A5
         ,  A6
         ,  A7
         ,  A8
         ,  A9
         ,  A10
         ,  A11
         ,  A12
         ,  A13
         ,  A14
         ,  Qty
         ,  QtyUnit
         ,  C_Address2
         ,  C_Address3
         ,  C_Address4
         ,  C_Zip
         ,  A1573     --CS01 S
         ,  A1574 
         ,  A1575 
         ,  A1576 
         ,  A158  
         ,  A159  
         ,  A161  
         ,  A162  
         ,  A163  
         ,  A164  
         ,  A165  
         ,  A166  
         ,  A167  
         ,  A168  
         ,  A171  
         ,  A172  
         ,  A173  
         ,  A174  
         ,  A175  
         ,  A176  
         ,  A177  
         ,  A178  
         ,  A181  
         ,  A182  
         ,  A183  
         ,  A184  
         ,  A152  
         ,  A153  
         ,  A154  
         ,  A155  
         ,  A156  
         ,  A1571 
         ,  A1572 
         ,  A151,C_country,C_state,CountryOfOrigin        --CS01 E
         ,  A20,A21,A169,A170,A179,A180                   --CS02
         )
   SELECT 1 as recgroup
         ,OD.Orderkey
         ,OD.Sku
         ,Descr =  ISNULL(S.descr,'')
         ,ExtOrderkey     = OH.Externorderkey
         ,Company         = OH.C_Company
         ,OH.OrderDate
         ,ISNULL(OH.userdefine02,'')
         ,ISNULL(OH.userdefine05,'')
         ,ISNULL(OH.C_Address1,'')
         ,A2 = ISNULL(MAX(CASE WHEN C.Code ='A2'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A3 = ISNULL(MAX(CASE WHEN C.Code ='A3'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A4 = ISNULL(MAX(CASE WHEN C.Code ='A4'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A5 = ISNULL(MAX(CASE WHEN C.Code ='A5'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A6 = ISNULL(MAX(CASE WHEN C.Code ='A6'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A7 = ISNULL(MAX(CASE WHEN C.Code ='A7'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A8 = ISNULL(MAX(CASE WHEN C.Code ='A8'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A9 = ISNULL(MAX(CASE WHEN C.Code ='A9'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A10 = ISNULL(MAX(CASE WHEN C.Code ='A10'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A11 = ISNULL(MAX(CASE WHEN C.Code ='A11'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A12 = ISNULL(MAX(CASE WHEN C.Code ='A12'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A13 = ISNULL(MAX(CASE WHEN C.Code ='A13'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,A14 = ISNULL(MAX(CASE WHEN C.Code ='A14'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,(PD.Qty)
         ,' X'
         ,ISNULL(OH.C_Address2,'')
         ,ISNULL(OH.C_Address3,'')
         ,ISNULL(OH.C_Address4,'')
         ,ISNULL(OH.C_Zip,'')
         ,ISNULL(MAX(CASE WHEN C.Code ='A1573'  THEN RTRIM(C.long) ELSE ' ' END),'')     --CS01 S
         ,ISNULL(MAX(CASE WHEN C.Code ='A1574'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A1575'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A1576'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A158'  THEN RTRIM(C.long) ELSE ' ' END),'')  
         ,ISNULL(MAX(CASE WHEN C.Code ='A159'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,ISNULL(MAX(CASE WHEN C.Code ='A161'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A162'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A163'  THEN RTRIM(C.long) ELSE ' ' END),'')  
         ,ISNULL(MAX(CASE WHEN C.Code ='A164'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A165'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A166'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A167'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A168'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A171'  THEN RTRIM(C.long) ELSE ' ' END),'')  
         ,ISNULL(MAX(CASE WHEN C.Code ='A172'  THEN RTRIM(C.long) ELSE ' ' END),'')  
         ,ISNULL(MAX(CASE WHEN C.Code ='A173'  THEN RTRIM(C.long) ELSE ' ' END),'')   
         ,ISNULL(MAX(CASE WHEN C.Code ='A174'  THEN RTRIM(C.long) ELSE ' ' END),'')   
         ,ISNULL(MAX(CASE WHEN C.Code ='A175'  THEN RTRIM(C.long) ELSE ' ' END),'')  
         ,ISNULL(MAX(CASE WHEN C.Code ='A176'  THEN RTRIM(C.long) ELSE ' ' END),'')   
         ,ISNULL(MAX(CASE WHEN C.Code ='A177'  THEN RTRIM(C.long) ELSE ' ' END),'')   
         ,ISNULL(MAX(CASE WHEN C.Code ='A178'  THEN RTRIM(C.long) ELSE ' ' END),'')  
         ,ISNULL(MAX(CASE WHEN C.Code ='A181'  THEN RTRIM(C.long) ELSE ' ' END),'')   
         ,ISNULL(MAX(CASE WHEN C.Code ='A182'  THEN RTRIM(C.long) ELSE ' ' END),'')  
         ,ISNULL(MAX(CASE WHEN C.Code ='A183'  THEN RTRIM(C.long) ELSE ' ' END),'')  
         ,ISNULL(MAX(CASE WHEN C.Code ='A184'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A152'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A153'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A154'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,ISNULL(MAX(CASE WHEN C.Code ='A155'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,ISNULL(MAX(CASE WHEN C.Code ='A156'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A1571'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A1572'  THEN RTRIM(C.long) ELSE ' ' END),'') 
         ,ISNULL(MAX(CASE WHEN C.Code ='A151'  THEN RTRIM(C.long) ELSE ' ' END),'')     
         , ISNULL(OH.C_Country,'') 
         , ISNULL(OH.C_State,'') 
         , ISNULL(OH.CountryOfOrigin,'') --CS01 E
         , ISNULL(MAX(CASE WHEN C.Code ='A20'  THEN RTRIM(C.long) ELSE ' ' END),'')  --CS02 S
         , ISNULL(MAX(CASE WHEN C.Code ='A21'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,ISNULL(MAX(CASE WHEN C.Code ='A169'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,ISNULL(MAX(CASE WHEN C.Code ='A170'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,ISNULL(MAX(CASE WHEN C.Code ='A179'  THEN RTRIM(C.long) ELSE ' ' END),'')
         ,ISNULL(MAX(CASE WHEN C.Code ='A180'  THEN RTRIM(C.long) ELSE ' ' END),'')     --CS02 E
   FROM ORDERDETAIL OD  WITH (NOLOCK)
   JOIN ORDERS      OH  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
   JOIN SKU S WITH (NOLOCK) ON s.storerkey = OD.storerkey AND S.sku = OD.sku
  -- JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = OD.ORDERKEY AND PD.SKU = OD.SKU AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER)
  --CROSS APPLY (SELECT pd.orderkey AS orderkey,pd.sku AS sku,SUM(pd.qty) AS qty 
  --             FROM dbo.PICKDETAIL pd WITH (NOLOCK) WHERE pd.OrderKey = OD.ORDERKEY AND PD.SKU = OD.SKU AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
  --              GROUP BY pd.orderkey,pd.sku ) AS pd
   CROSS APPLY (SELECT PD.ORDERKEY AS ORDERKEY , PD.SKU AS SKU , SUM(PD.QTY) AS QTY
   FROM DBO.PICKDETAIL AS PD WITH(NOLOCK)
   WHERE PD.ORDERKEY = OD.ORDERKEY AND PD.SKU = OD.SKU
       /*AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER*/
   GROUP BY PD.ORDERKEY , PD.SKU ) AS PD
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'RTNENCONST' AND C.UDF02 = @c_Facility AND C.storerkey = OH.Storerkey
   WHERE OH.Orderkey = @c_Orderkey
   AND OH.C_ISOCntryCode = @c_C_ISOCntryCode
   AND OH.Facility = @c_Facility
   GROUP BY OD.Orderkey
         ,OD.Sku
         ,ISNULL(OH.userdefine02,'')
         ,ISNULL(OH.userdefine05,'')
         ,ISNULL(S.descr,'')
         ,OH.Externorderkey
         ,OH.C_Company
         ,OH.OrderDate
         ,ISNULL(OH.C_Address1,'')
         ,ISNULL(OH.C_Address2,'')
         ,ISNULL(OH.C_Address3,'')
         ,ISNULL(OH.C_Address4,'')
         ,ISNULL(OH.C_Zip,'')
         ,ISNULL(OH.C_Country,'')        --CS01
         ,ISNULL(OH.C_State,'')          --CS01
         ,ISNULL(OH.CountryOfOrigin,'')  --CS01
         ,pd.qty                          --CS02
   ORDER BY OD.SKU

   SELECT @n_MaxRec = COUNT(1) FROM #TMP_RDTNOTE03RDT

   SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno

   WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)
   BEGIN
   INSERT INTO #TMP_RDTNOTE03RDT
         (  recgroup
         ,  Orderkey
         ,  Sku
         ,  Descr
         ,  ExtOrderkey
         ,  Company
         ,  OrderDate
         ,  OHUDF02
         ,  OHUDF05
         ,  C_Address1
         ,  A2
         ,  A3
         ,  A4
         ,  A5
         ,  A6
         ,  A7
         ,  A8
         ,  A9
         ,  A10
         ,  A11
         ,  A12
         ,  A13
         ,  A14
         ,  Qty
         ,  QtyUnit
         ,  C_Address2
         ,  C_Address3
         ,  C_Address4
         ,  C_Zip
         ,  A1573     --CS01 S
         ,  A1574 
         ,  A1575 
         ,  A1576 
         ,  A158  
         ,  A159  
         ,  A161  
         ,  A162  
         ,  A163  
         ,  A164  
         ,  A165  
         ,  A166  
         ,  A167  
         ,  A168  
         ,  A171  
         ,  A172  
         ,  A173  
         ,  A174  
         ,  A175  
         ,  A176  
         ,  A177  
         ,  A178  
         ,  A181  
         ,  A182  
         ,  A183  
         ,  A184  
         ,  A152  
         ,  A153  
         ,  A154  
         ,  A155  
         ,  A156  
         ,  A1571 
         ,  A1572 
         ,  A151 ,C_country,C_state,CountryOfOrigin       --CS01 E
         ,  A20,A21,A169,A170,A179,A180                   --CS02
         )
   SELECT TOP 1 recgroup
         ,  Orderkey
         ,  NULL
         ,  NULL
         ,  ExtOrderkey
         ,  Company
         ,  OrderDate
         ,  NULL
         ,  NULL
         ,  C_Address1
         ,  A2
         ,  A3
         ,  A4
         ,  A5
         ,  A6
         ,  A7
         ,  A8
         ,  A9
         ,  A10
         ,  A11
         ,  A12
         ,  A13
         ,  A14
         ,  NULL
         ,  NULL
         ,  C_Address2
         ,  C_Address3
         ,  C_Address4
         ,  C_Zip
         ,  A1573     --CS01 S
         ,  A1574
         ,  A1575
         ,  A1576
         ,  A158 
         ,  A159 
         ,  A161 
         ,  A162 
         ,  A163 
         ,  A164 
         ,  A165 
         ,  A166 
         ,  A167 
         ,  A168 
         ,  A171 
         ,  A172 
         ,  A173 
         ,  A174 
         ,  A175 
         ,  A176 
         ,  A177 
         ,  A178 
         ,  A181 
         ,  A182 
         ,  A183 
         ,  A184 
         ,  A152 
         ,  A153 
         ,  A154 
         ,  A155 
         ,  A156 
         ,  A1571
         ,  A1572
         ,  A151    
         , C_Country 
         , C_State 
         , CountryOfOrigin --CS01 E
         ,  A20,A21,A169,A170,A179,A180     --CS02
   FROM #TMP_RDTNOTE03RDT T_INV
   Order BY SKU

   SET @n_CurrentRec = @n_CurrentRec + 1
   END

   SELECT   recgroup
         ,  Orderkey
         ,  Sku
         ,  Descr
         ,  ExtOrderkey
         ,  Company
         ,  OrderDate
         ,  A2
         ,  A3
         ,  A4
         ,  A5
         ,  A6
         ,  A7
         ,  A8
         ,  A9
         ,  A10
         ,  A11
         ,  A12
         ,  A13
         ,  A14
         ,  Qty
         ,  QtyUnit
         ,  CAST(Qty as NVARCHAR(5)) + QtyUnit AS QtyWithPF
         ,  C_Address1
         ,  C_Address2
         ,  C_Address3
         ,  C_Address4
         ,  C_Zip
         ,  OHUDF02
         ,  OHUDF05
         ,  A1573     --CS01 S
         ,  A1574 
         ,  A1575 
         ,  A1576 
         ,  A158  
         ,  A159  
         ,  A161  
         ,  A162  
         ,  A163  
         ,  A164  
         ,  A165  
         ,  A166  
         ,  A167  
         ,  A168  
         ,  A171  
         ,  A172  
         ,  A173  
         ,  A174  
         ,  A175  
         ,  A176  
         ,  A177  
         ,  A178  
         ,  A181  
         ,  A182  
         ,  A183  
         ,  A184  
         ,  A152  
         ,  A153  
         ,  A154  
         ,  A155  
         ,  A156  
         ,  A1571 
         ,  A1572 
         ,  A151        
         , C_Country 
         , C_State 
         , CountryOfOrigin --CS01 E
         ,  A20,A21,A169,A170,A179,A180                   --CS02
   FROM #TMP_RDTNOTE03RDT T_INV
   Order BY CASE WHEN SKU <> '' THEN 1 ELSE 2 END

   GOTO QUIT

QUIT:
   IF OBJECT_ID('tempdb..#TMP_RDTNOTE03RDT') IS NOT NULL
      DROP TABLE #TMP_RDTNOTE03RDT
END

GO