SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_POD_17                                              */
/* Creation Date: 27-JUNE-2018                                          */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-5012 - [CN] - GBG POD- migrate from Hyperion to WMS     */
/*        :                                                             */
/* Called By: r_dw_pod_17                                               */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_POD_17]
           @c_MBOLKey   NVARCHAR(10),
           @c_exparrivaldate  NVARCHAR(30) = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @n_NoOfLine        INT
          
DECLARE 
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_condition3      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_ExecArguments   NVARCHAR(4000),
      @c_SQLInsert       NVARCHAR(4000)


   SET @n_StartTCnt = @@TRANCOUNT
   
   SET @n_NoOfLine = 16

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   
   CREATE TABLE #TMP_POD17
      (  RowID          INT IDENTITY (1,1) NOT NULL 
      ,  MBOLKey         NVARCHAR(10)   NULL  DEFAULT('')
      ,  ConsigneeKey   NVARCHAR(45)   NULL  DEFAULT('')
      ,  Orderkey       NVARCHAR(10)   NULL  DEFAULT('')
      ,  C_Company      NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address1     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_DESCR        NVARCHAR(80)   NULL  DEFAULT('')
      ,  C_Long         NVARCHAR(80)   NULL  DEFAULT('')
      ,  C_Contact1     NVARCHAR(30)   NULL  DEFAULT('')
      ,  C_Phone1       NVARCHAR(18)   NULL  DEFAULT('')
      ,  PQty           INT            NULL  DEFAULT(0)
      ,  TTLCTN         INT            NULL  DEFAULT(0)
      ,  Loadkey        NVARCHAR(20)   NULL  DEFAULT('')
     ,  MCUBE          FLOAT          NULL
     ,  ExtOrderkey    NVARCHAR(30)   NULL  DEFAULT('')
     ,  OHNotes        NVARCHAR(50)   NULL  DEFAULT('')
       )


   SET @c_condition1 = ''
   SET @c_condition2 = ''
   SET @c_condition3 = ''
   SET @c_SQLGroup = ''
   SET @c_SQLOrdBy = ''

   SET @c_SQLGroup = N' GROUP BY OH.consigneekey,OH.c_company,ISNULL(OH.C_Address1,'''')  ,' + CHAR(13) +
                      'C.[description],C.long,OH.Externorderkey,ISNULL(OH.c_contact1,''''),  ' + CHAR(13) +
                      'ISNULL(OH.c_phone1,''''),OH.loadkey,MD.mbolkey,oh.storerkey,oh.orderkey,' + CHAR(13) +
                      'MD.totalcartons,MD.[cube],OH.notes'

   SET @c_SQLOrdBy = ' ORDER BY MD.mbolkey,OH.loadkey,oh.orderkey'
  -- select @c_mbolkey '@c_mbolkey'

   IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK) WHERE OH.MBOLKEY = @c_mbolkey)
   BEGIN 
      SET @c_condition1 = ' WHERE MD.mbolkey = @c_mbolkey '
      --select @c_condition1 '@c_condition1'
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK) WHERE OH.ORDERKEY = @c_mbolkey)
   BEGIN
     SET @c_condition1 = ' WHERE OH.ORDERKEY = @c_mbolkey '
   END
           
    SET @c_SQLInsert = ''
    SET @c_SQLInsert ='INSERT INTO #TMP_POD17 (MBOLKey ,ConsigneeKey,Orderkey,C_Company,' + CHAR(13) +
                      'C_Address1,C_descr,C_Long,C_Contact1,C_Phone1,PQty,TTLCTN,Loadkey,MCUBE,ExtOrderkey,OHNotes ) ' 
 
    SET @c_SQLJOIN = 'SELECT DISTINCT MD.mbolkey,OH.consigneekey,oh.orderkey,OH.c_company,' + CHAR(13) +
                     ' ISNULL(OH.C_Address1,'''') as Add1,C.[description],C.long, ISNULL(OH.c_contact1,''''), ' + CHAR(13) +
                     ' ISNULL(OH.c_phone1,''''),sum(PD.qty) as PQTY,MD.totalcartons,OH.loadkey, ' + CHAR(13) +
                     ' MD.[cube],OH.Externorderkey,OH.Notes ' + CHAR(13) +
                     ' FROM  ORDERS OH WITH (NOLOCK) ' + CHAR(13) +
                  -- ' JOIN MBOL MB WITH (NOLOCK) on MB.mbolkey=oh.mbolkey' + CHAR(13) +
                     ' JOIN MBOLDETAIL MD WITH (NOLOCK) ON MD.loadkey=OH.loadkey' + CHAR(13) +
                     ' JOIN orderdetail OD WITH (NOLOCK) ON OD.orderkey = OH.Orderkey ' + CHAR(13) +
                     ' JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OD.Orderkey ' + CHAR(13) +
                     '                            AND PD.sku = OD.sku AND PD.orderlinenumber=OD.Orderlinenumber' + CHAR(13) +
                     '   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname=''SFFAC'' '  
                  

        SET @c_ExecArguments = N'@c_mbolkey       NVARCHAR(10)'

      
          
   SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN + CHAR(13) + @c_condition1 + CHAR(13) + @c_SQLGroup + CHAR(13) + @c_SQLOrdBy

   --select @c_SQL '@c_SQL'
      
    EXEC sp_executesql   @c_SQL  
                       , @c_ExecArguments  
                       , @c_mbolkey  

   SELECT  MBOLKey ,ExtOrderkey,C_Company,Orderkey,
           C_Address1,ConsigneeKey,C_descr,C_Long,C_Contact1,     
           PQty,TTLCTN,MCUBE,Loadkey,C_Phone1,OHNotes
   FROM #TMP_POD17

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO