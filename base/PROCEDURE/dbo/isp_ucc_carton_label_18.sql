SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_UCC_Carton_Label_18                            */
/* Creation Date: 04-Aug-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: ChewKP                                                   */
/*                                                                      */
/* Purpose: Loreal UCC Carton Label                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 04-08-2010   ChewKP    SOS#183534 Created                            */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_18] (
       @cStorerKey   NVARCHAR(15), 
       @cDropID    NVARCHAR(18)
)
AS
BEGIN
	SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   

   DECLARE @n_continue    int,
           @c_errmsg      NVARCHAR(255),
           @b_success     int,
           @n_err         int, 
           @b_debug       int
   
   SET @b_debug = 0

   DECLARE @c_PickSlipNo   NVARCHAR(10),
           @n_MinCartonNo  int,
           @n_MaxCartonNo  int,
           @n_Count        int,
           @n_CartonNo     int,
           @c_Orderkey     NVARCHAR(10)
   
   
   SET @n_MinCartonNo = 0
   SET @n_MaxCartonNo = 0
   SET @n_Count = 0
   SET @n_CartonNo = 0
   SET @c_Orderkey = ''
   
           
           
--           @cUserID       NVARCHAR(18) -- (YokeBeen01)

   DECLARE @t_Result Table (
           	DropID         NVARCHAR(18) NULL,
            LoadKey        NVARCHAR(10) NULL,
            OrderKey       NVARCHAR(10) NULL,
            DeliveryDate   datetime NULL,
            InvoiceNo      NVARCHAR(20) NULL,
            ExternOrderKey NVARCHAR(30) NULL,
            ConsigneeKey   NVARCHAR(15) NULL,
            Route          NVARCHAR(10) NULL,
            BuyerPO        NVARCHAR(20) NULL,
            C_Company      NVARCHAR(45) NULL,
            C_Address1     NVARCHAR(45) NULL,
            C_Address2     NVARCHAR(45) NULL,
            C_Address3     NVARCHAR(45) NULL,
            C_Address4     NVARCHAR(45) NULL,
            C_City         NVARCHAR(45) NULL,
            C_Zip          NVARCHAR(18) NULL,
            Qty            int NULL, 
            CartonCnt      int NULL,
            CartonNo       int NULL
			  )

   
--   DECLARE @t_CartonNo Table (
--      Storerkey NVARCHAR(15) NULL,
--      DropID    NVARCHAR(18) NULL,
--      CartonNo  int NULL
--   )
   
   -- Insert Label Result To Temp Table
   INSERT INTO @t_Result 
   SELECT PD.DropID , 
   ORDERS.LoadKey, 
   ORDERS.Orderkey, 
   ORDERS.DeliveryDate, 
   ORDERS.InvoiceNO, 
   ORDERS.ExternOrderkey, 
   ORDERS.ConsigneeKey,
   ORDERS.Route, 
   ORDERS.BuyerPO, 
   ORDERS.C_Company, 
   ORDERS.C_Address1, 
   ORDERS.C_Address2, 
   ORDERS.C_Address3,
   ORDERS.C_Address4, 
   ORDERS.C_City, 
   ORDERS.C_Zip,
   SUM(PD.QTY),
   0,
   0
   FROM PickDetail PD WITH (NOLOCK) 
   INNER JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.ORDERKEY = PD.ORDERKEY) 
   WHERE PD.Storerkey = @cStorerKey AND PD.DropID = @cDropID 
   GROUP BY 
   PD.DropID , 
   ORDERS.LoadKey, 
   ORDERS.Orderkey, 
   ORDERS.DeliveryDate, 
   ORDERS.InvoiceNO, 
   ORDERS.ExternOrderkey, 
   ORDERS.ConsigneeKey,
   ORDERS.Route, 
   ORDERS.BuyerPO, 
   ORDERS.C_Company, 
   ORDERS.C_Address1, 
   ORDERS.C_Address2, 
   ORDERS.C_Address3,
   ORDERS.C_Address4, 
   ORDERS.C_City,
   ORDERS.C_Zip
   
   
   SELECT TOP 1 @c_Orderkey = Orderkey FROM @t_Result

   SELECT @c_PickSlipNo = PickSlipNo FROM PACKHEADER WITH (NOLOCK)
   WHERE Orderkey = @c_Orderkey
   
   SELECT @n_MaxCartonNo = MAX(CartonNo) FROM PACKDETAIL WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   AND Storerkey = @cStorerKey

   SELECT @n_MinCartonNo = CartonNo FROM PACKDETAIL WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo AND DropID = @cDropID 
   AND Storerkey = @cStorerKey


   UPDATE @t_Result 
   SET CartonCnt = @n_MaxCartonNo,
       CartonNo = @n_MinCartonNo

   
   
   -- Insert Carton No to Temp Table
--   INSERT INTO @t_CartonNo
--   SELECT  @cStorerKey, @cDropID, PACKD.CartonNo 
--   FROM PickDetail PD WITH (NOLOCK) 
--   INNER JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.ORDERKEY = PD.ORDERKEY) 
--   INNER JOIN PACKHEADER PH WITH (NOLOCK) ON (PH.ORDERKEY = ORDERS.ORDERKEY AND PH.STORERKEY = ORDERS.STORERKEY)
--   INNER JOIN PACKDETAIL PACKD WITH (NOLOCK) ON (PACKD.PickSlipNo = PH.PickSlipNo AND PACKD.Storerkey = PH.Storerkey)
--   WHERE PD.Storerkey = @cStorerKey AND PACKD.DropID = @cDropID 
--   GROUP BY PACKD.CartonNo
      
--   SELECT @n_MaxCartonNo  = MAX(CartonNo) FROM @t_CartonNo
--   SELECT @n_MinCartonNo  = MIN(CartonNo) FROM @t_CartonNo
   
--   SET @n_CartonNo = @n_MinCartonNo

--   WHILE @n_CartonNo  <= @n_MaxCartonNo 
--   BEGIN
--   
--      IF @n_Count = 0
--      BEGIN
--      
--         UPDATE @t_Result
--         SET CartonCnt = @n_MaxCartonNo,
--             CartonNo = @n_MinCartonNo
--      END
--      ELSE 
--      BEGIN
--      
--         INSERT INTO @t_Result
--         SELECT TOP 1 DropID      ,
--               LoadKey        ,
--               OrderKey       ,
--               DeliveryDate   ,
--               InvoiceNo      ,
--               ExternOrderKey ,
--               ConsigneeKey   ,
--               Route          ,
--               BuyerPO        ,
--               C_Company      ,
--               C_Address1     ,
--               C_Address2     ,
--               C_Address3     ,
--               C_Address4     ,
--               C_City         ,
--               C_Zip          ,
--               Qty            , 
--               @n_MaxCartonNo ,
--               @n_CartonNo    
--         FROM @t_Result
--         
--      END
--          
--         --SELECT @n_CartonNo '@n_CartonNo' , @n_MaxCartonNo   '@n_MaxCartonNo'  
--
--         SET @n_Count = @n_Count + 1 
--         SET @n_CartonNo = @n_MinCartonNo + @n_Count
--         
--
--   END

     

   SELECT * FROM @t_Result 
	--Select 'UserID' , '1' , '65491003' , 'SC SHADOW PINTUCK   90WHITE' , '10' , '16/07/2010' , '90001857' ,'DETAIL'  , ''      
	--Select 'ckpname' , '1' , '65491003' , 'SC SHADOW PINTUCK   90WHITE' , '10' , '16/07/2010' , '90001857' ,'HEADER'  , '4' , '65491099'   
   
END



GO