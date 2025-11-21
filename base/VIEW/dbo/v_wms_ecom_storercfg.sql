SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_WMS_ECOM_STORERCFG] AS


SELECT SC.StorerKey
      ,SC.SValue
      ,SC.Configkey
      ,CL.Description
      ,SC.Option1
      ,SC.Option5
FROM CODELKUP CL WITH (NOLOCK)
JOIN STORERCONFIG SC WITH (NOLOCK) ON (CL.Code = SC.Configkey)
WHERE CL.ListName = 'STORERCFG'
AND SC.Configkey IN (  'ValidateTrackNo'
                     , 'CTNTypeInput'
                     , 'DefaultCTNType'
                     , 'WeightInput'
                     , 'CheckMaxWeight'
                     , 'AutoCalcWeight'
                     , 'EcomAutoPackConfirm'
                     , 'MultiPackMode'
                     )
/*
SELECT StorerKey
      ,SValue
      ,Configkey
      ,ConfigDesc = 'Validate track # against Orders.Userdefine04/Orders.TrackingNo on the first carton'
      ,Option1
      ,Option5
FROM STORERCONFIG WITH (NOLOCK)
WHERE Configkey = 'ValidateTrackNo'
UNION
SELECT StorerKey
      ,SValue
      ,Configkey
      ,ConfigDesc = 'Show 10 top carton type for the storer on ecom packing screen and set Carton Type to mandatory field'
      ,Option1
      ,Option5
FROM STORERCONFIG WITH (NOLOCK)
WHERE Configkey = 'CTNTypeInput'
UNION
SELECT StorerKey
      ,SValue
      ,Configkey
      ,ConfigDesc = 'To Default carton type from the 1st shown carton type in the list'
      ,Option1
      ,Option5
FROM STORERCONFIG WITH (NOLOCK)
WHERE Configkey = 'DefaultCTNType'
UNION
SELECT StorerKey
      ,SValue
      ,Configkey
      ,ConfigDesc = 'To set Weight to mandatory field'
      ,Option1
      ,Option5
FROM STORERCONFIG WITH (NOLOCK)
WHERE Configkey = 'WeightInput'
UNION
SELECT StorerKey
      ,SValue
      ,Configkey
      ,ConfigDesc = 'To check the input weight is below Carton Maximum Weight setup in Cartonization or SValue'
      ,Option1
      ,Option5
FROM STORERCONFIG WITH (NOLOCK)
WHERE Configkey = 'CheckMaxWeight'
UNION
SELECT StorerKey
      ,SValue
      ,Configkey
      ,ConfigDesc = 'Auto calculate carton weight from total packed sku.stdgrossweight plus carton weight setup by in cartonization'
      ,Option1
      ,Option5
FROM STORERCONFIG WITH (NOLOCK)
WHERE Configkey = 'AutoCalcWeight'
UNION
SELECT StorerKey
      ,SValue
      ,Configkey
      ,ConfigDesc = 'Set to enable Auto packconfirm at ECOM Packing, SValue: 1-Single, 2-Multi, 3-Both'
      ,Option1
      ,Option5
FROM STORERCONFIG WITH (NOLOCK)
WHERE Configkey = 'EcomAutoPackConfirm'
UNION
SELECT StorerKey
      ,SValue
      ,Configkey
      ,ConfigDesc = 'Set to multi pack by userid / computer, svalue, option1: blank/userid/computer'
      ,Option1
      ,Option5
FROM STORERCONFIG WITH (NOLOCK)
WHERE Configkey = 'MultiPackMode'
*/

GO