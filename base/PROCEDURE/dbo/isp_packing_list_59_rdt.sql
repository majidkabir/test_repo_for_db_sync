SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_Packing_List_59_rdt                            */    
/* Creation Date: 22-Feb-2019                                           */    
/* Copyright: IDS                                                       */    
/* Written by: WLCHOOI                                                  */    
/*                                                                      */    
/* Purpose: WMS-8063 - [CN]_FRISO_ECOM Packing List                     */    
/*                                                                      */    
/*                                                                      */    
/* Called By: report dw = r_dw_Packing_List_59_rdt                      */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */  
/* 18-Jan-2020  CSCHOMG   1.1   WMS-16022 add new field (CS01)          */  
/************************************************************************/    
    
CREATE PROC [dbo].[isp_Packing_List_59_rdt] (    
   @c_Pickslipno NVARCHAR(20) = ''
   ,@c_StorerKey NVARCHAR(30) = ''  
   ,@c_OrderKey  NVARCHAR(20) = ''   
   ,@c_ExtOrdKey NVARCHAR(60) = ''  
   ,@c_EcomOrdID NVARCHAR(90) = ''   
  -- ,@b_debug     INT          = 0 
)     
AS     
BEGIN    
   SET NOCOUNT ON    
  -- SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF
   
   DECLARE @n_Continue              INT
         , @c_SQL                   NVARCHAR(4000)
         , @c_SQLJOIN               NVARCHAR(4000)  
         , @c_condition1            NVARCHAR(150)
         , @c_condition2            NVARCHAR(150)
         , @c_condition3            NVARCHAR(150)
         , @c_condition4            NVARCHAR(150)
         , @c_ExecArguments         NVARCHAR(4000)
         , @b_Success               INT
         , @n_StartTCnt             INT
         , @n_maxline               INT               --CS01


   DECLARE @n_Err         INT          
   DECLARE @c_ErrMsg      NVARCHAR(250)  
   DECLARE @b_debug       INT = 0

   IF @c_Pickslipno = NULL SET @c_Pickslipno = ''
   IF @c_StorerKey  = NULL SET @c_StorerKey  = ''
   IF @c_OrderKey   = NULL SET @c_OrderKey   = ''
   IF @c_ExtOrdKey  = NULL SET @c_ExtOrdKey  = ''
   IF @c_EcomOrdID  = NULL SET @c_EcomOrdID  = ''

   CREATE TABLE #TEMP_PACKLIST59RDT(
      Pickslipno       NVARCHAR(20) NULL
      ,STCompany       NVARCHAR(90) NULL
      ,STAddress       NVARCHAR(300) NULL
      ,STCity          NVARCHAR(90) NULL
      ,STContact1      NVARCHAR(60) NULL
      ,EcomOrderID     NVARCHAR(90) NULL
      ,PmtDate         DATETIME NULL
      ,C_Company       NVARCHAR(90) NULL
      ,C_Contact1      NVARCHAR(60) NULL
      ,C_Zip           NVARCHAR(36) NULL
      ,C_Phone1        NVARCHAR(36) NULL
      ,C_City          NVARCHAR(90) NULL
      ,C_Address       NVARCHAR(300) NULL
      ,SKU             NVARCHAR(40) NULL
      ,OriginalQty     INT NULL
      ,ExtendedField   NVARCHAR(250) NULL
      ,AltSku          NVARCHAR(20)  NULL           --CS01
      ,Recgrp          INT                          --CS01
   )

   SET @n_continue   = 1
   SET @c_condition1 = ''
   SET @c_condition2 = ''        
   SET @c_condition3 = ''
   SET @c_condition4 = ''
   SET @c_ExecArguments = N'   @c_Pickslipno       NVARCHAR(20)'  
                              +' ,@c_StorerKey        NVARCHAR(30) ' 
                              +' ,@c_Orderkey         NVARCHAR(20) ' 
                              +' ,@c_ExtOrdKey        NVARCHAR(60) '
                              +' ,@c_EcomOrdID        NVARCHAR(90) '
                              +' ,@n_maxline          INT '              --CS01

   SET @n_maxline = 6                --CS01
   SET @n_Err    = 0
   SET @c_ErrMsg = ''
   SELECT @n_StartTCnt=@@TRANCOUNT

   IF ISNULL(RTRIM(@c_StorerKey),'') <> ''
   BEGIN
      SET @c_condition1 = 'AND ORDERS.Storerkey = RTRIM(@c_StorerKey)'
   END

   IF ISNULL(RTRIM(@c_OrderKey),'') <> ''
   BEGIN
      SET @c_condition2 = 'AND ORDERS.Orderkey = RTRIM(@c_OrderKey)'
   END

   IF ISNULL(RTRIM(@c_ExtOrdKey),'') <> ''
   BEGIN
      SET @c_condition3 = 'AND ORDERS.ExternOrderKey = RTRIM(@c_ExtOrdKey)'
   END

   IF ISNULL(RTRIM(@c_EcomOrdID),'') <> ''
   BEGIN
      SET @c_condition4 = 'AND OrderInfo.EcomOrderID = RTRIM(@c_EcomOrdID)'
   END

   --Check print from View Report, storerkey is compulsory
   IF(ISNULL(RTRIM(@c_Pickslipno),'')='' AND ISNULL(RTRIM(@c_StorerKey),'')='')
   BEGIN
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63500    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Storerkey is Blank. (isp_Packing_List_59_rdt)'
         GOTO QUIT 
   END

   --Check print from View Report, OrderKey, ExtOrdKey, EcomOrdID should have either one
   IF (ISNULL(RTRIM(@c_OrderKey),'') = '' AND ISNULL(RTRIM(@c_ExtOrdKey),'') = '' AND ISNULL(RTRIM(@c_EcomOrdID),'') = '' AND ISNULL(RTRIM(@c_Pickslipno),'') = '')
   BEGIN
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63510    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': OrderKey & ExtOrdKey & EcomOrdID are Blank (isp_Packing_List_59_rdt)'
         GOTO QUIT 
   END

   --Find pickslipno if blank
   IF((@n_continue = 1 OR @n_continue = 2) AND @c_Pickslipno = '')
   BEGIN
      SELECT @c_Pickslipno = PackHeader.PickSlipNo
      FROM PACKHEADER (NOLOCK)
      JOIN ORDERS (NOLOCK) ON PACKHEADER.STORERKEY = ORDERS.STORERKEY AND PACKHEADER.ORDERKEY = ORDERS.ORDERKEY
      JOIN OrderInfo (NOLOCK) ON OrderInfo.OrderKey = ORDERS.OrderKey
      WHERE ORDERS.StorerKey = RTRIM(@c_StorerKey)
      AND Orders.Orderkey       = CASE WHEN @c_OrderKey  = '' THEN Orders.Orderkey        ELSE @c_OrderKey END
      AND Orders.ExternOrderKey = CASE WHEN @c_ExtOrdKey = '' THEN Orders.ExternOrderKey  ELSE @c_ExtOrdKey END
      AND OrderInfo.EcomOrderID = CASE WHEN @c_EcomOrdID = '' THEN OrderInfo.EcomOrderID  ELSE @c_EcomOrdID END
   END
   
   IF((@n_continue = 1 OR @n_continue = 2)  AND @c_Pickslipno <> '')
   BEGIN
      SET @c_SQL= 'INSERT INTO #TEMP_PACKLIST59RDT(Pickslipno,STCompany,STAddress,STCity,STContact1,EcomOrderID,PmtDate,C_Company ' + CHAR(13) +
                                                  ',C_Contact1,C_Zip,C_Phone1,C_City,C_Address,SKU,OriginalQty,ExtendedField,altsku,Recgrp)'       --CS01            

      SET @c_SQLJOIN = + 'SELECT PACKHEADER.Pickslipno' + CHAR(13)
            +', Storer.Company' + CHAR(13)
            +', ISNULL(RTRIM(Storer.Address1),'''') + '' '' + ISNULL(LTRIM(RTRIM(Storer.Address2)),'''') + '' '' + ISNULL(LTRIM(RTRIM(Storer.Address3)),'''')' + CHAR(13)
            +', ISNULL(Storer.City,'''')' + CHAR(13)
            +', ISNULL(Storer.Contact1,'''')' + CHAR(13)
            +', OrderInfo.EcomOrderID' + CHAR(13)
            +', OrderInfo.PmtDate' + CHAR(13)
            +', Orders.C_Company' + CHAR(13)
            +', Orders.C_Contact1' + CHAR(13)
            +', Orders.C_Zip' + CHAR(13)
            +', Orders.C_Phone1' + CHAR(13)
            +', Orders.C_City' + CHAR(13)
            +', ISNULL(RTRIM(Orders.C_Address2),'''') + '' '' +  ISNULL(LTRIM(RTRIM(Orders.C_Address3)),'''')+ '' '' +  ISNULL(LTRIM(RTRIM(Orders.C_Address4)),'''')' + CHAR(13)
            +', OrderDetail.SKU' + CHAR(13)
            +', OrderDetail.OriginalQty' + CHAR(13)
            +', RTRIM(SKUInfo.ExtendedField01) + '' '' + LTRIM(RTRIM(SKUInfo.ExtendedField02)) , S.Altsku ' + CHAR(13)                  --CS01  
            +', (Row_Number() OVER (PARTITION BY PACKHEADER.Pickslipno,OrderInfo.EcomOrderID ORDER BY OrderInfo.EcomOrderID,OrderDetail.SKU Asc)-1)/@n_maxLine + 1 AS recgrp'         + CHAR(13)                  --CS01        
            +'FROM ORDERS (NOLOCK)' + CHAR(13)
            +'JOIN ORDERDETAIL (NOLOCK) ON ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY AND ORDERS.StorerKey = ORDERDETAIL.StorerKey' + CHAR(13)
            +'JOIN OrderInfo (NOLOCK) ON OrderInfo.OrderKey = ORDERS.OrderKey' + CHAR(13)
            +'JOIN SKUINFO (NOLOCK) ON ORDERDETAIL.SKU = SKUINFO.Sku AND SKUINFO.Storerkey = ORDERS.StorerKey' + CHAR(13)
            +'JOIN PACKHEADER (NOLOCK) ON PACKHEADER.STORERKEY = ORDERS.STORERKEY AND PACKHEADER.ORDERKEY = ORDERS.ORDERKEY' + CHAR(13)
            +'JOIN STORER (NOLOCK) ON STORER.StorerKey = ORDERS.StorerKey' + CHAR(13)
            +'JOIN SKU S WITH (NOLOCK) ON S.storerkey = ORDERDETAIL.Storerkey AND S.SKU =ORDERDETAIL.Sku ' + CHAR(13)
            +'WHERE PACKHEADER.Pickslipno = @c_Pickslipno '

      IF(@b_debug = 1)
      BEGIN
         PRINT @c_SQLJOIN
      END

      SET @c_SQL = @c_SQL + @c_SQLJOIN  + @c_condition1 +  CHAR(13) + @c_condition2  + CHAR(13) + @c_condition3 + CHAR(13) + @c_condition4
   
      IF(@b_debug = 1)
      BEGIN
         PRINT @c_SQL
      END     
   
      EXEC sp_ExecuteSql     @c_SQL     
                           , @c_ExecArguments    
                           , @c_Pickslipno
                           , @c_StorerKey
                           , @c_Orderkey
                           , @c_ExtOrdKey 
                           , @c_EcomOrdID
                           , @n_maxline                 --CS01

   END

   
   IF(@n_continue = 1 OR @n_continue = 2)
   SELECT * FROM #TEMP_PACKLIST59RDT

QUIT:   
IF @n_Continue=3  -- Error Occured - Process And Return    
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_Packing_List_59_rdt'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
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