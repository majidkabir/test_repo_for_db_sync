SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Stored Procedure: isp_GSIReturnLabel                                          */
/* Creation Date: 17-Feb-2012                                                    */
/* Copyright: IDS                                                                */
/* Written by: NJOW                                                              */
/*                                                                               */
/* Purpose:  SOS#236488 - Generate GS1 UPS Return Label                          */
/*                                                                               */
/* Called By: RCM from Loadplan/Packing/MBOL Modules/RDT                         */
/*                                                                               */
/* PVCS Version: 1.0                                                             */
/*                                                                               */
/* Version: 5.4                                                                  */
/*                                                                               */
/* Data Modifications:                                                           */
/*                                                                               */
/* Updates:                                                                      */
/* Date           Author      Ver.  Purposes                                     */
/* 06-Mar-2012    NJOW01      1.0   236488-Change sorting to labelline           */
/* 19-Mar-2012    Ung         1.1   Add RDT compatible message                   */
/* 24-APR-2012    Adrian      1.2   Suppress Address1 and Address2 when flag     */
/*                                  sent in b_fax1 = N  --AAY001                 */
/*********************************************************************************/
CREATE PROC [dbo].[isp_GSIReturnLabel] (
     @c_Pickslipno      NVARCHAR(10)   = ''
   , @c_CartonNoParm  NVARCHAR(5)   = ''
   , @c_TemplateID    NVARCHAR(60)  = ''
   , @c_PrinterID     NVARCHAR(215) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE @n_StartTCnt      int
         , @n_continue       int
         , @c_errmsg         NVARCHAR(255)
         , @b_success        int
         , @n_err            int
         , @n_IsRDT          int
         , @c_createheader   NVARCHAR(1)
         , @c_FullLineText   NVARCHAR(MAX)
         , @c_reprint        NVARCHAR(1)

   DECLARE @c_storerkey      NVARCHAR(15)
         , @c_facility       NVARCHAR(5)
         , @n_CartonNoParm   int
         , @c_Dischargeplace NVARCHAR(30)
         , @c_CartonWeight   NVARCHAR(20)
         , @c_LabelNo        NVARCHAR(20)
         , @c_LabelLine      NVARCHAR(5) --NJOW01

   DECLARE @c_refzip         NVARCHAR(5)
         , @c_RouteCode      NVARCHAR(20)
         , @c_Address        NVARCHAR(25)
         , @c_City           NVARCHAR(25)
         , @c_State          NVARCHAR(10)
         , @c_Zip            NVARCHAR(10)

   DECLARE @c_Field01 NVARCHAR(100) ,@c_Field11 NVARCHAR(100) ,@c_Field21 NVARCHAR(100) ,@c_Field31 NVARCHAR(100) ,@c_Field41 NVARCHAR(100) ,@c_Field51 NVARCHAR(100)
          ,@c_Field02 NVARCHAR(100) ,@c_Field12 NVARCHAR(100) ,@c_Field22 NVARCHAR(100) ,@c_Field32 NVARCHAR(100) ,@c_Field42 NVARCHAR(100) ,@c_Field52 NVARCHAR(100)
          ,@c_Field03 NVARCHAR(100) ,@c_Field13 NVARCHAR(100) ,@c_Field23 NVARCHAR(100) ,@c_Field33 NVARCHAR(100) ,@c_Field43 NVARCHAR(100) ,@c_Field53 NVARCHAR(100)
          ,@c_Field04 NVARCHAR(100) ,@c_Field14 NVARCHAR(100) ,@c_Field24 NVARCHAR(100) ,@c_Field34 NVARCHAR(100) ,@c_Field44 NVARCHAR(100) ,@c_Field54 NVARCHAR(100)
          ,@c_Field05 NVARCHAR(100) ,@c_Field15 NVARCHAR(100) ,@c_Field25 NVARCHAR(100) ,@c_Field35 NVARCHAR(100) ,@c_Field45 NVARCHAR(100) ,@c_Field55 NVARCHAR(100)
          ,@c_Field06 NVARCHAR(100) ,@c_Field16 NVARCHAR(100) ,@c_Field26 NVARCHAR(100) ,@c_Field36 NVARCHAR(100) ,@c_Field46 NVARCHAR(100) ,@c_Field56 NVARCHAR(100)
          ,@c_Field07 NVARCHAR(100) ,@c_Field17 NVARCHAR(100) ,@c_Field27 NVARCHAR(100) ,@c_Field37 NVARCHAR(100) ,@c_Field47 NVARCHAR(100) ,@c_Field57 NVARCHAR(100)
          ,@c_Field08 NVARCHAR(100) ,@c_Field18 NVARCHAR(100) ,@c_Field28 NVARCHAR(100) ,@c_Field38 NVARCHAR(100) ,@c_Field48 NVARCHAR(100) ,@c_Field58 NVARCHAR(100)
          ,@c_Field09 NVARCHAR(100) ,@c_Field19 NVARCHAR(100) ,@c_Field29 NVARCHAR(100) ,@c_Field39 NVARCHAR(100) ,@c_Field49 NVARCHAR(100) ,@c_Field59 NVARCHAR(100)
          ,@c_Field10 NVARCHAR(100) ,@c_Field20 NVARCHAR(100) ,@c_Field30 NVARCHAR(100) ,@c_Field40 NVARCHAR(100) ,@c_Field50 NVARCHAR(100)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0

   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_XML'),'') = ''
   BEGIN
      CREATE TABLE #TempGSICartonLabel_XML
               ( SeqNo Int IDENTITY(1,1) Primary key,
                 LineText NVARCHAR(MAX) )
   END

   IF ISNULL(RTRIM(@c_CartonNoParm),'') <> '' AND ISNUMERIC(@c_CartonNoParm) = 1
   BEGIN
      SET @n_CartonNoParm = CAST(@c_CartonNoParm AS Int)
   END

   SELECT @c_StorerKey = ORDERS.StorerKey, @c_facility = FACILITY.Facility, @c_refzip = LEFT(ISNULL(FACILITY.Userdefine04,''),5),
          @c_PrinterID = ISNULL(LTRIM(RTRIM(FACILITY.UserDefine19)),'') + ISNULL(LTRIM(@c_PrinterID),''),
          @c_dischargeplace = ORDERS.Dischargeplace
   FROM ORDERS (NOLOCK)
   JOIN PACKHEADER (NOLOCK) ON ORDERS.Orderkey = PACKHEADER.Orderkey
   JOIN FACILITY (NOLOCK) ON ORDERS.FACILITY = FACILITY.FACILITY
   WHERE PACKHEADER.Pickslipno = @c_Pickslipno

   SELECT @c_Address = CASE WHEN CHARINDEX('POBOX',@c_dischargeplace) > 0 THEN address_pobox ELSE address_basic END,
          @c_City = CASE WHEN CHARINDEX('POBOX',@c_dischargeplace) > 0 THEN city_pobox ELSE city_basic END,
          @c_State = CASE WHEN CHARINDEX('POBOX',@c_dischargeplace) > 0 THEN state_pobox ELSE state_basic END,
          @c_Zip = CASE WHEN CHARINDEX('POBOX',@c_dischargeplace) > 0 THEN zip_pobox ELSE zip_basic END,
          @c_RouteCode = RouteCode
   FROM USPSAddress (NOLOCK)
   WHERE ref_zip = @c_refzip

   SELECT @c_CartonWeight = LTRIM(CONVERT(VARCHAR(20),SUM(PD.Qty * SKU.Stdgrosswgt))), @c_labelno = MAX(ISNULL(PD.Labelno,''))
   FROM PACKDETAIL PD (NOLOCK)
   JOIN SKU (NOLOCK) ON (PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku)
   WHERE PD.Pickslipno = @c_Pickslipno
   AND PD.Cartonno = @n_CartonNoParm

   IF (SELECT COUNT(1) FROM UPSReturnTrackNo (NOLOCK)
       WHERE Pickslipno = @c_Pickslipno AND Labelno = @c_labelno AND Reprint = 'Y') > 0
   BEGIN
      SET @c_reprint = 'Y'
   END

   IF @n_Continue in(1,2)
   BEGIN
      DECLARE CUR_RTNLBL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT PD.LabelLine, --NJOW01
--                '',    -- #1 Facility ship from name
                LEFT(ISNULL(S.Company,''), 45),    -- #1 Facility ship from name
                SUBSTRING(ISNULL(F.Descr,''), 1,25),  --#2 Facility shipping address 1
                SUBSTRING(ISNULL(F.Descr,''), 26,25),  --#3 Facility shipping address 2
                LEFT(ISNULL(F.UserDefine01,''), 25),  --#4 Facility shipping city
                LEFT(ISNULL(F.UserDefine03,''), 10),  --#5 Facility shipping state
                LEFT(ISNULL(F.UserDefine04,''), 10),  --#6 Facility shipping zip code
                LEFT(ISNULL(S.Company,''), 25),   --#7 Storer name
                LEFT(ISNULL(O.Facility,''), 5),  --#8 Facility number
                LEFT(ISNULL(O.C_Phone1,''), 18),  --#9 Ship to consignee phone
                LEFT(ISNULL(O.C_Contact1,''), 30),  --#10 UPS ship to person
                LEFT(ISNULL(O.C_Country,''), 30),  --#11 UPS ship to country iso
                LEFT(ISNULL(O.Consigneekey,''), 10),  --#12 Ship to consignee
                LEFT(ISNULL(O.C_Company,''), 45), --#13 Ship to consignee name
/*AAY001
                LEFT(ISNULL(O.C_Address1,''), 45), --#14 Ship to consignee address 1
                LEFT(ISNULL(O.C_Address2,''), 45), --#15 Ship to consignee address 2
*/ --AAY001
				CASE WHEN UPPER(ISNULL(O.B_FAX1,'')) = 'N' THEN
                          ''
                          ELSE LEFT(ISNULL(O.C_Address1,''), 45)
                 END,
                
				CASE WHEN UPPER(ISNULL(O.B_FAX1,'')) = 'N' THEN
                          ''
                          ELSE LEFT(ISNULL(O.C_Address2,''), 45)
                 END,
--AAY001 END

                LEFT(ISNULL(O.C_City,''), 45), --#16 Ship to consignee city
                LEFT(ISNULL(O.C_State,''), 45), --#17 Ship to consignee state
                LEFT(ISNULL(O.C_Zip,''), 18), --#18 Ship to consignee zip
                LEFT(ISNULL(O.C_ISOCntryCode,''), 10), --#19 Ship to iso country code
--                LEFT(ISNULL(O.M_Phone2,''), 18), --#20 UPS service indicator --AAYXXX
--                LEFT(ISNULL(O.M_Fax1,''), 18), --#21 Shipper account no --AAYXXX
                (SELECT LEFT(ISNULL(CODELKUP.SHORT,''),18) FROM CODELKUP (NOLOCK)  --#21
				 WHERE CODELKUP.LISTNAME=@c_StorerKey AND RIGHT(CODELKUP.CODE,3)=@c_facility
				 ),
                (SELECT LEFT(ISNULL(CODELKUP.LONG,''),18) FROM CODELKUP (NOLOCK) --#22
				 WHERE CODELKUP.LISTNAME=@c_StorerKey AND RIGHT(CODELKUP.CODE,3)=@c_facility
				 ),
                LEFT(ISNULL(O.M_Fax2,''), 18), --#22 Shipment no
                CASE WHEN ISNULL(O.M_Company,'') = '' THEN --#23 Final destination consignee name
                          LEFT(ISNULL(O.C_Company,''), 45)
                     ELSE LEFT(ISNULL(O.M_Company,''), 45) END,
/*
                CASE WHEN ISNULL(O.M_Address1,'') = '' THEN --#24 Final destination consignee address 1
                          LEFT(ISNULL(O.C_Address1,''), 45)
                     ELSE LEFT(ISNULL(O.M_Address1,''), 45) END,
                CASE WHEN ISNULL(O.M_Address2,'') = '' THEN --#25 Final destination consignee address 2
                          LEFT(ISNULL(O.C_Address2,''), 45)
                     ELSE LEFT(ISNULL(O.M_Address2,''), 45) END,
*/
-- AAY001 START
				CASE WHEN UPPER(ISNULL(O.B_FAX1,'')) = 'N' THEN
                          ''
                          ELSE (
                CASE WHEN ISNULL(O.M_Address1,'') = '' THEN 
                          LEFT(ISNULL(O.C_Address1,''), 45)
                     ELSE LEFT(ISNULL(O.M_Address1,''), 45) END)
                 END,
                
				CASE WHEN UPPER(ISNULL(O.B_FAX1,'')) = 'N' THEN
                          ''
                          ELSE (
                CASE WHEN ISNULL(O.M_Address2,'') = '' THEN 
                          LEFT(ISNULL(O.C_Address2,''), 45)
                     ELSE LEFT(ISNULL(O.M_Address2,''), 45) END)
                 END,
-- AAY001 END

                CASE WHEN ISNULL(O.M_City,'') = '' THEN --#26 Final destination consignee city
                          LEFT(ISNULL(O.C_City,''), 45)
                     ELSE LEFT(ISNULL(O.M_City,''), 45) END,
                CASE WHEN ISNULL(O.M_State,'') = '' THEN --#27 Final destination consignee state
                          LEFT(ISNULL(O.C_State,''), 45)
                     ELSE LEFT(ISNULL(O.M_State,''), 45) END,
                CASE WHEN ISNULL(O.M_Zip,'') = '' THEN --#28 Final destination consignee zip
                          LEFT(ISNULL(O.C_Zip,''), 18)
                     ELSE LEFT(ISNULL(O.M_Zip,''), 18) END,
                CASE WHEN ISNULL(O.MarkForKey,'') = '' THEN --#29 Final destination consigne store
                          LEFT(ISNULL(O.Consigneekey,''), 10)
                     ELSE LEFT(ISNULL(O.MarkForKey,''), 10) END,
                LEFT(ISNULL(O.B_Contact2,''), 30), --#30 UPS class of service
                LEFT(ISNULL(O.BuyerPO,''), 20), --#31 Pick ticket no
                LEFT(ISNULL(O.Orderkey,''), 10), --#32 WMS orderkey
--                LEFT(ISNULL(@c_CartonWeight,''),5), --#33 Carton weight
                LEFT(ISNULL(SKU.Stdgrosswgt,''),5), --#33 Carton weight --AAY20120227
                CASE WHEN ISNULL(M.USERDEFINE07,'') = '' THEN --#34 Julian day of pickup
                          RIGHT(DBO.TO_JULIAN(GETDATE()),3)
                     ELSE RIGHT(DBO.TO_JULIAN(M.USERDEFINE07),3) END,
                LEFT(ISNULL(@c_RouteCode,''), 15), --#35 3PS route code
                LEFT(ISNULL(O.C_Fax2,''), 18), --#36 UPS service title
                LEFT(ISNULL(O.C_Fax1,''), 18), --#37 UPS service icon
                LEFT(ISNULL(RTN.RefNo01,''), 30), --#38 UPS Return tracking no
                Suser_Sname(), --#39 Printed by
                CONVERT(char(8),Getdate(),1)+' '+convert(char(8),Getdate(),108), --#40 File create date time stamp
                '', --#41 Mark for address 3
                '', --#42 Bill to address 3
                '', --#43 Ship to address 3
                '', --#44 Reserve 1
                '', --#45 Reserve 2
                '', --#46 Reserve 3
                '', --#47 Reserve 4
                '', --#48 Reserve 5
                '', --#49 Reserve 6
                '', --#50 Reserve 7
                '', --#51 Reserve 8
                '', --#52 Reserve 9
                '', --#53 Reserve 10
                LEFT(ISNULL(SKU.Style,''), 15), --#54 Item 1 Style
                LEFT(ISNULL(SKU.Color,''), 8), --#55 Item 1 Color
                LEFT(ISNULL(SKU.Measurement,''), 5), --#56 Item 1 Mearesurement
                LEFT(ISNULL(SKU.Size,''), 15), --#57 Item 1 Size
                LEFT(ISNULL(OD.Sku,''), 36), --#58 Item 1 GTIN12
                LEFT(ISNULL(OD.Userdefine01,''), 18) --#59 Item 1 Name
          FROM PACKHEADER PH (NOLOCK)
               JOIN (SELECT Pickslipno, Labelno, Cartonno, Sku, Min(LabelLine) AS LabelLine
                     FROM PACKDETAIL (NOLOCK)
                     WHERE Pickslipno = @c_Pickslipno AND Cartonno = @n_CartonNoParm
                     GROUP BY Pickslipno, Labelno, Cartonno, Sku) AS PD ON (PH.Pickslipno = PD.Pickslipno)
               JOIN ORDERS O (NOLOCK) ON (PH.Orderkey = O.Orderkey)
               JOIN FACILITY F (NOLOCK) ON (O.Facility = F.Facility)
               JOIN STORER S (NOLOCK) ON (O.Storerkey = S.Storerkey)
               JOIN UPSReturnTrackNo RTN ON (PH.Pickslipno = RTN.Pickslipno AND PD.Labelno = RTN.Labelno AND PD.Sku = RTN.Sku AND O.Orderkey = RTN.Orderkey)
               JOIN ORDERDETAIL OD ON (RTN.Orderkey = OD.Orderkey AND RTN.OrderLineNumber = OD.OrderLineNumber)
               JOIN SKU (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku)
               LEFT JOIN MBOLDETAIL MD (NOLOCK) ON (O.Orderkey = MD.Orderkey)
               LEFT JOIN MBOL M (NOLOCK) ON (MD.Mbolkey = M.Mbolkey)
          WHERE PH.Pickslipno = @c_Pickslipno
          AND PD.Cartonno = @n_CartonNoParm
          AND (RTN.Reprint = 'Y' OR @c_reprint <> 'Y')
          ORDER BY PD.LabelLine, LEFT(ISNULL(RTN.RefNo01,''), 30)  --NJOW01

      OPEN CUR_RTNLBL
      FETCH NEXT FROM CUR_RTNLBL INTO @c_LabelLine --NJOW01
                                     ,@c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05 ,@c_Field06
                                     ,@c_Field07, @c_Field08, @c_Field09 ,@c_Field10, @c_Field11, @c_Field12
                                     ,@c_Field13, @c_Field14, @c_Field15 ,@c_Field16, @c_Field17, @c_Field18
                                     ,@c_Field19, @c_Field20, @c_Field21 ,@c_Field22, @c_Field23, @c_Field24
                                     ,@c_Field25, @c_Field26, @c_Field27 ,@c_Field28, @c_Field29, @c_Field30
                                     ,@c_Field31, @c_Field32, @c_Field33 ,@c_Field34, @c_Field35, @c_Field36
                                     ,@c_Field37, @c_Field38, @c_Field39 ,@c_Field40, @c_Field41, @c_Field42
                                     ,@c_Field43, @c_Field44, @c_Field45 ,@c_Field46, @c_Field47, @c_Field48
                                     ,@c_Field49, @c_Field50, @c_Field51 ,@c_Field52, @c_Field52, @c_Field54
                                     ,@c_Field55, @c_Field56, @c_Field57 ,@c_Field58, @c_Field59

      SELECT @c_createheader = 'Y', @c_FullLineText = ''

      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	 IF @c_createheader = 'Y'
      	 BEGIN
      	    IF @n_IsRDT = 1
            BEGIN
               INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
               VALUES ('%BTW% /AF=N"' + ISNULL(RTRIM(@c_TemplateID),'') + '" /PRN="' + ISNULL(RTRIM(@c_PrinterID),'') + '" /PrintJobName="' + ISNULL(RTRIM(@c_LabelNo),'')+ '" /R=3 /C=1 /P /D="%Trigger File Name%" ', @@SPID)

               INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
               VALUES ('%END%', @@SPID)
            END
            ELSE
            BEGIN
               INSERT INTO #TempGSICartonLabel_XML (LineText)
               VALUES ('%BTW% /AF=N"' + ISNULL(RTRIM(@c_TemplateID),'') + '" /PRN="' + ISNULL(RTRIM(@c_PrinterID),'') + '" /PrintJobName="' + ISNULL(RTRIM(@c_LabelNo),'')+ '" /R=3 /C=1 /P /D="%Trigger File Name%" ' )

               INSERT INTO #TempGSICartonLabel_XML (LineText)
               VALUES ('%END%')
            END
            SET @c_createheader = 'N'
         END

/*
         SET @c_FullLineText = RTRIM(@c_Field01)+','+RTRIM(@c_Field02)+','+RTRIM(@c_Field03)+','+RTRIM(@c_Field04)+','+RTRIM(@c_Field05)+','+RTRIM(@c_Field06)
                          +','+RTRIM(@c_Field07)+','+RTRIM(@c_Field08)+','+RTRIM(@c_Field09)+','+RTRIM(@c_Field10)+','+RTRIM(@c_Field11)+','+RTRIM(@c_Field12)
                          +','+RTRIM(@c_Field13)+','+RTRIM(@c_Field14)+','+RTRIM(@c_Field15)+','+RTRIM(@c_Field16)+','+RTRIM(@c_Field17)+','+RTRIM(@c_Field18)
                          +','+RTRIM(@c_Field19)+','+RTRIM(@c_Field20)+','+RTRIM(@c_Field21)+','+RTRIM(@c_Field22)+','+RTRIM(@c_Field23)+','+RTRIM(@c_Field24)
                          +','+RTRIM(@c_Field25)+','+RTRIM(@c_Field26)+','+RTRIM(@c_Field27)+','+RTRIM(@c_Field28)+','+RTRIM(@c_Field29)+','+RTRIM(@c_Field30)
                          +','+RTRIM(@c_Field31)+','+RTRIM(@c_Field32)+','+RTRIM(@c_Field33)+','+RTRIM(@c_Field34)+','+RTRIM(@c_Field35)+','+RTRIM(@c_Field36)
                          +','+RTRIM(@c_Field37)+','+RTRIM(@c_Field38)+','+RTRIM(@c_Field39)+','+RTRIM(@c_Field40)+','+RTRIM(@c_Field41)+','+RTRIM(@c_Field42)
                          +','+RTRIM(@c_Field43)+','+RTRIM(@c_Field44)+','+RTRIM(@c_Field45)+','+RTRIM(@c_Field46)+','+RTRIM(@c_Field47)+','+RTRIM(@c_Field48)
                          +','+RTRIM(@c_Field49)+','+RTRIM(@c_Field50)+','+RTRIM(@c_Field51)+','+RTRIM(@c_Field52)+','+RTRIM(@c_Field52)+','+RTRIM(@c_Field54)
                          +','+RTRIM(@c_Field55)+','+RTRIM(@c_Field56)+','+RTRIM(@c_Field57)+','+RTRIM(@c_Field58)+','+RTRIM(@c_Field59)
*/

         SET @c_FullLineText = '"'+RTRIM(@c_Field01)+'","'+RTRIM(@c_Field02)+'","'+RTRIM(@c_Field03)+'","'+RTRIM(@c_Field04)+'","'+RTRIM(@c_Field05)+'","'+RTRIM(@c_Field06)
                          +'","'+RTRIM(@c_Field07)+'","'+RTRIM(@c_Field08)+'","'+RTRIM(@c_Field09)+'","'+RTRIM(@c_Field10)+'","'+RTRIM(@c_Field11)+'","'+RTRIM(@c_Field12)
                          +'","'+RTRIM(@c_Field13)+'","'+RTRIM(@c_Field14)+'","'+RTRIM(@c_Field15)+'","'+RTRIM(@c_Field16)+'","'+RTRIM(@c_Field17)+'","'+RTRIM(@c_Field18)
                          +'","'+RTRIM(@c_Field19)+'","'+RTRIM(@c_Field20)+'","'+RTRIM(@c_Field21)+'","'+RTRIM(@c_Field22)+'","'+RTRIM(@c_Field23)+'","'+RTRIM(@c_Field24)
                          +'","'+RTRIM(@c_Field25)+'","'+RTRIM(@c_Field26)+'","'+RTRIM(@c_Field27)+'","'+RTRIM(@c_Field28)+'","'+RTRIM(@c_Field29)+'","'+RTRIM(@c_Field30)
                          +'","'+RTRIM(@c_Field31)+'","'+RTRIM(@c_Field32)+'","'+RTRIM(@c_Field33)+'","'+RTRIM(@c_Field34)+'","'+RTRIM(@c_Field35)+'","'+RTRIM(@c_Field36)
                          +'","'+RTRIM(@c_Field37)+'","'+RTRIM(@c_Field38)+'","'+RTRIM(@c_Field39)+'","'+RTRIM(@c_Field40)+'","'+RTRIM(@c_Field41)+'","'+RTRIM(@c_Field42)
                          +'","'+RTRIM(@c_Field43)+'","'+RTRIM(@c_Field44)+'","'+RTRIM(@c_Field45)+'","'+RTRIM(@c_Field46)+'","'+RTRIM(@c_Field47)+'","'+RTRIM(@c_Field48)
                          +'","'+RTRIM(@c_Field49)+'","'+RTRIM(@c_Field50)+'","'+RTRIM(@c_Field51)+'","'+RTRIM(@c_Field52)+'","'+RTRIM(@c_Field52)+'","'+RTRIM(@c_Field54)
                          +'","'+RTRIM(@c_Field55)+'","'+RTRIM(@c_Field56)+'","'+RTRIM(@c_Field57)+'","'+RTRIM(@c_Field58)+'","'+RTRIM(@c_Field59)+'"'


      	 IF @n_IsRDT = 1
            INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
            VALUES (@c_FullLineText, @@SPID)
         ELSE
            INSERT INTO #TempGSICartonLabel_XML (LineText)
            VALUES (@c_FullLineText)

         FETCH NEXT FROM CUR_RTNLBL INTO @c_LabelLine --NJOW01
                                        ,@c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05 ,@c_Field06
                                        ,@c_Field07, @c_Field08, @c_Field09 ,@c_Field10, @c_Field11, @c_Field12
                                        ,@c_Field13, @c_Field14, @c_Field15 ,@c_Field16, @c_Field17, @c_Field18
                                        ,@c_Field19, @c_Field20, @c_Field21 ,@c_Field22, @c_Field23, @c_Field24
                                        ,@c_Field25, @c_Field26, @c_Field27 ,@c_Field28, @c_Field29, @c_Field30
                                        ,@c_Field31, @c_Field32, @c_Field33 ,@c_Field34, @c_Field35, @c_Field36
                                        ,@c_Field37, @c_Field38, @c_Field39 ,@c_Field40, @c_Field41, @c_Field42
                                        ,@c_Field43, @c_Field44, @c_Field45 ,@c_Field46, @c_Field47, @c_Field48
                                        ,@c_Field49, @c_Field50, @c_Field51 ,@c_Field52, @c_Field52, @c_Field54
                                        ,@c_Field55, @c_Field56, @c_Field57 ,@c_Field58, @c_Field59
      END
      CLOSE CUR_RTNLBL
      DEALLOCATE CUR_RTNLBL
   END

   IF @c_reprint = 'Y'
   BEGIN
      UPDATE UPSReturnTrackNo WITH (ROWLOCK)
      SET Reprint = 'N'
      WHERE Pickslipno = @c_Pickslipno AND Labelno = @c_labelno AND Reprint = 'Y'
   END

   IF @n_IsRDT <> 1
   BEGIN
      IF OBJECT_ID('tempdb..#TMP_GSICartonLabel_XML') IS NOT NULL
      BEGIN
         INSERT INTO #TMP_GSICartonLabel_XML
         SELECT * FROM #TempGSICartonLabel_XML
         ORDER BY seqno
      END
   END

QUIT:

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      --DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1 -- (ChewKP05)
      BEGIN
          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
          -- Instead we commit and raise an error back to parent, let the parent decide

          -- Commit until the level we begin with
          WHILE @@TRANCOUNT > @n_starttcnt
             COMMIT TRAN

          -- Raise error with severity = 10, instead of the default severity 16.
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
          RAISERROR (@n_err, 10, 1) WITH SETERROR

          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GSIReturnLabel'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

SET QUOTED_IDENTIFIER OFF

GO