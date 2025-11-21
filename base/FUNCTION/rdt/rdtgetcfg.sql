SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtGetCfg                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-03-21 1.1  TLTING     SQL2012                                   */
/************************************************************************/

CREATE   Function [RDT].[rdtGetCfg] (@nFunction_ID int, @cConfig NVARCHAR(10), @cStorerkey NVARCHAR(10)='' )
returns int
as
BEGIN
	DECLARE @nValue int 

        SELECT @nValue = ISNULL(ISNULL(ISNULL(c.value,b.value),A.value),1) 
        FROM RDTCfg_SYS A (NOLOCK)
		LEFT OUTER JOIN RDTCfg_User B (NOLOCK) ON A.Function_ID = B.Function_ID AND A.Config = B.Config
		LEFT OUTER JOIN RDTCfg_User C (NOLOCK) ON A.Function_ID = C.Function_ID AND A.Config = C.Config
        WHERE B.Storerkey = '' 
		AND C.StorerKey=@cStorerkey 
        AND A.Function_ID = @nFunction_ID 
		AND A.Config = @cConfig
         
        RETURN ISNULL(@nValue,1)
END

GO